#= require hamlcoffee
#= require_tree ./templates
#= require_self
angular.module('myApp',  ["myApp.controllers", "myApp.directives", "myApp.services"])

angular.module('myApp.services', [])
  .factory "mapService", ($rootScope) ->
      mapService = {}
      mapService.map = undefined
      mapService.set_map = (map) ->
        this.map = map
        $rootScope.$broadcast('handleMapSet')
      return mapService
     

angular.module('myApp.directives', [])
  .directive('appVersion', ['version', (version)->
    (scope, elm, attrs)->
      elm.text(version)
  ])
  
  .directive "map", (mapService) ->    
    replace: true
    template: "<div></div>"
    link: (scope, element, attrs) ->
      mapOptions =
        zoom: 3
        center: new google.maps.LatLng(24.026397, 14.765625)
        mapTypeId: google.maps.MapTypeId.ROADMAP
      mapService.set_map new google.maps.Map(document.getElementById("map"), mapOptions)
        
angular.module("myApp.controllers", [])
  .controller "myCtrl", ($scope) ->
    canvasLayer                = undefined
    $scope.gl                  = undefined
    $scope.pointProgram        = undefined
    $scope.pointArrayBuffer    = undefined
    $scope.colorLookup         = {}
    
    pixelsToWebGLMatrix  = new Float32Array(16)
    mapMatrix            = new Float32Array(16)
    $scope.shaderProgram = undefined

    
    $scope.cities = [{"id":"Algiers", "latitude": 36.70000, "longitude": 3.21700} ,{"id": "Khartoum", "latitude": 15.56670, "longitude": 32.60000 },{"id": "New York", "latitude": 40.75170, "longitude": -73.99420},{"id": "London", "latitude": 51.50722, "longitude": -0.12750}, {"id": "Bogota", "latitude": 4.63330, "longitude": -74.09990}, {"id": "Paris", "latitude": 48.85000, "longitude": 2.33330}]
    $scope.init = ->

      # initialize the map
      mapOptions =
        zoom: 3
        center: new google.maps.LatLng(24.026397, 14.765625)
        mapTypeId: google.maps.MapTypeId.ROADMAP
      $scope.map = new google.maps.Map(document.getElementById("map"), mapOptions)

      
    $scope.initialize_canvasLayer = ->
      canvasLayerOptions =
        map: $scope.map
        resizeHandler: resize
        animate: false
        updateHandler: $scope.update

      canvasLayer = new CanvasLayer(canvasLayerOptions)
      # initialize WebGL
      $scope.gl = canvasLayer.canvas.getContext("experimental-webgl",
        preserveDrawingBuffer: true
      )
      canvas = document.getElementById("map")
 
      
      canvas.addEventListener 'mousemove', (ev) ->
        x    = undefined
        y    = undefined
        top  = 0
        left = 0
        obj  = canvas
        while obj and obj.tagName isnt "BODY"
          top  += obj.offsetTop
          left += obj.offsetLeft
          obj   = obj.offsetParent
        left += window.pageXOffset
        top  -= window.pageYOffset
        x     = ev.clientX - left
        y     = canvas.clientHeight - (ev.clientY - top)         
        pixels = new Uint8Array(4)
        $scope.gl.bindFramebuffer($scope.gl.FRAMEBUFFER, $scope.framebuffer)              # Load offscreen frame buffer for picking
        $scope.gl.readPixels x, y, 1, 1, $scope.gl.RGBA, $scope.gl.UNSIGNED_BYTE, pixels
        $scope.gl.bindFramebuffer($scope.gl.FRAMEBUFFER, null)
        d = document.getElementById('infoWindow')
        if $scope.colorLookup[pixels[0] + " " + pixels[1] + " " + pixels[2]]
          d.style.display = "inline"
          d.style.left    = ev.x + 10 + 'px'
          d.style.top     = ev.y - 15 + 'px'
          d.innerHTML     = $scope.colorLookup[pixels[0] + " " + pixels[1] + " " + pixels[2]]
        else
          d.style.display = "none"        
      
      $scope.animate()

    $scope.createShaderProgram = ->
      # create vertex shader
      vertexSrc    = document.getElementById("pointVertexShader").text
      vertexShader = $scope.gl.createShader($scope.gl.VERTEX_SHADER)
      $scope.gl.shaderSource vertexShader, vertexSrc
      $scope.gl.compileShader vertexShader

      # create fragment shader
      fragmentSrc    = document.getElementById("pointFragmentShader").text
      fragmentShader = $scope.gl.createShader($scope.gl.FRAGMENT_SHADER)
      $scope.gl.shaderSource fragmentShader, fragmentSrc
      $scope.gl.compileShader fragmentShader

      # link shaders to create our program
      $scope.pointProgram  = $scope.gl.createProgram()
      $scope.gl.attachShader $scope.pointProgram, vertexShader
      $scope.gl.attachShader $scope.pointProgram, fragmentShader
      $scope.gl.linkProgram  $scope.pointProgram
      $scope.gl.useProgram   $scope.pointProgram       
      
 
    $scope.animate = ->
      city_dots                       = point_data($scope.cities)
      $scope.point_xy                 = city_dots.point_xy               # Typed array of x, y pairs
      $scope.point_off_screen_color   = city_dots.point_off_screen_color # Typed array of sets of four floating points
      $scope.point_on_screen_color    = city_dots.point_on_screen_color  # Typed array of sets of four floating points
      $scope.point_size               = city_dots.point_size
    
    
      $scope.pointArrayBuffer = $scope.gl.createBuffer()                                         # pointArrayBuffer
      $scope.gl.bindBuffer $scope.gl.ARRAY_BUFFER, $scope.pointArrayBuffer
      $scope.gl.bufferData $scope.gl.ARRAY_BUFFER, city_dots.point_xy, $scope.gl.STATIC_DRAW

      
      $scope.sizeArrayBuffer = $scope.gl.createBuffer()                                          # SizeArrayBuffer
      $scope.gl.bindBuffer $scope.gl.ARRAY_BUFFER, $scope.sizeArrayBuffer
      $scope.gl.bufferData $scope.gl.ARRAY_BUFFER, city_dots.point_size, $scope.gl.STATIC_DRAW

      $scope.colorArrayBuffer = $scope.gl.createBuffer()                                         # On screen ColorArrayBuffer
      $scope.gl.bindBuffer $scope.gl.ARRAY_BUFFER, $scope.colorArrayBuffer
      $scope.gl.bufferData $scope.gl.ARRAY_BUFFER, city_dots.point_on_screen_color, $scope.gl.STATIC_DRAW

      $scope.colorArrayBufferOffScreen = $scope.gl.createBuffer()                                 # Off screen ColorArrayBuffer
      $scope.gl.bindBuffer $scope.gl.ARRAY_BUFFER, $scope.colorArrayBufferOffScreen
      $scope.gl.bufferData $scope.gl.ARRAY_BUFFER, city_dots.point_off_screen_color, $scope.gl.STATIC_DRAW    
    
    
    
    resize = ->
      width  = canvasLayer.canvas.width
      height = canvasLayer.canvas.height
      $scope.gl.viewport 0, 0, width, height
    
      # matrix which maps pixel coordinates to WebGL coordinates
      pixelsToWebGLMatrix.set [2 / width, 0, 0, 0, 0, -2 / height, 0, 0, 0, 0, 0, 0, -1, 1, 0, 1]


    
    $scope.update = (mapService) ->

      $scope.gl.clear $scope.gl.COLOR_BUFFER_BIT
      currentZoom = $scope.map.zoom
      mapProjection = $scope.map.getProjection()

      ###
      We need to create a transformation that takes world coordinate
      points in the pointArrayBuffer to the coodinates WebGL expects.
      1. Start with second half in pixelsToWebGLMatrix, which takes pixel
      coordinates to WebGL coordinates.
      2. Scale and translate to take world coordinates to pixel coords
      see https://developers.google.com/maps/documentation/javascript/maptypes#MapCoordinate
      ###

      # copy pixel->webgl matrix
      mapMatrix.set pixelsToWebGLMatrix

      # Scale to current zoom (worldCoords * 2^zoom)
      scale = Math.pow(2, $scope.map.zoom)
      scaleMatrix mapMatrix, scale, scale

      # translate to current view (vector from topLeft to 0,0)

      offset = mapProjection.fromLatLngToPoint(canvasLayer.getTopLeft())
      translateMatrix mapMatrix, -offset.x, -offset.y

      # attach matrix value to 'mapMatrix' uniform in shader
      matrixLoc = $scope.gl.getUniformLocation($scope.pointProgram, "mapMatrix")
      $scope.gl.uniformMatrix4fv matrixLoc, false, mapMatrix

      # attach matrix value to 'mapMatrix' uniform in shader
      resizeLoc = $scope.gl.getUniformLocation($scope.pointProgram, "resize_value")
      $scope.gl.uniform1f resizeLoc, $scope.point_size
     
      # Off SCREEN
      # Bind Shader attributes
      height = 1024
      width  = 1024
      # Creating a texture to store colors
      texture = $scope.gl.createTexture()
      $scope.gl.bindTexture $scope.gl.TEXTURE_2D, texture
      $scope.gl.texImage2D $scope.gl.TEXTURE_2D, 0, $scope.gl.RGBA, width, height, 0, $scope.gl.RGBA, $scope.gl.UNSIGNED_BYTE, null
      
      # Creating a Renderbuffer to store depth information
      renderbuffer = $scope.gl.createRenderbuffer()
      $scope.gl.bindRenderbuffer $scope.gl.RENDERBUFFER, renderbuffer
      $scope.gl.renderbufferStorage $scope.gl.RENDERBUFFER, $scope.gl.DEPTH_COMPONENT16, width, height
      
      # Creating a framebuffer for offscreen rendering
      $scope.framebuffer = $scope.gl.createFramebuffer()
      $scope.gl.bindFramebuffer $scope.gl.FRAMEBUFFER, $scope.framebuffer
      $scope.gl.framebufferTexture2D $scope.gl.FRAMEBUFFER, $scope.gl.COLOR_ATTACHMENT0, $scope.gl.TEXTURE_2D, texture, 0
      $scope.gl.framebufferRenderbuffer $scope.gl.FRAMEBUFFER, $scope.gl.DEPTH_ATTACHMENT, $scope.gl.RENDERBUFFER, renderbuffer

      # Finally, we do a bit of cleaning up as usual
      $scope.gl.bindTexture $scope.gl.TEXTURE_2D, null
      $scope.gl.bindRenderbuffer $scope.gl.RENDERBUFFER, null
      $scope.gl.bindFramebuffer $scope.gl.FRAMEBUFFER, null


      # OFF SCREEN
      # Bind Shader attributes
      $scope.gl.bindFramebuffer($scope.gl.FRAMEBUFFER, $scope.framebuffer);
      $scope.gl.bindBuffer($scope.gl.ARRAY_BUFFER, $scope.pointArrayBuffer)           # Bind world coord
      attributeLoc = $scope.gl.getAttribLocation($scope.pointProgram, "worldCoord")
      $scope.gl.enableVertexAttribArray attributeLoc
      $scope.gl.vertexAttribPointer attributeLoc, 2, $scope.gl.FLOAT, false, 0, 0
      
      $scope.gl.bindBuffer($scope.gl.ARRAY_BUFFER, $scope.sizeArrayBuffer)            # Bind point size
      attributeSize = $scope.gl.getAttribLocation($scope.pointProgram, "aPointSize")
      $scope.gl.enableVertexAttribArray attributeSize
      $scope.gl.vertexAttribPointer attributeSize, 1, $scope.gl.FLOAT, false, 0, 0

      $scope.gl.bindBuffer($scope.gl.ARRAY_BUFFER, $scope.colorArrayBufferOffScreen)    # Bind point color
      attributeCol = $scope.gl.getAttribLocation($scope.pointProgram, "color")
      $scope.gl.enableVertexAttribArray attributeCol     
      $scope.gl.vertexAttribPointer attributeCol, 4, $scope.gl.FLOAT, false, 0, 0
      
      # tell webgl how buffer is laid out (pairs of x,y coords)
      
      #l = $scope.current_service.rawPoints.length / 2
      l = $scope.point_xy.length / 2

      $scope.gl.drawArrays $scope.gl.POINTS, 0, l
      $scope.gl.bindFramebuffer $scope.gl.FRAMEBUFFER, null
      
      
      
      # On SCREEN
      # Bind Shader attributes
      $scope.gl.bindBuffer($scope.gl.ARRAY_BUFFER, $scope.pointArrayBuffer)           # Bind world coord
      attributeLoc = $scope.gl.getAttribLocation($scope.pointProgram, "worldCoord")
      $scope.gl.enableVertexAttribArray attributeLoc
      $scope.gl.vertexAttribPointer attributeLoc, 2, $scope.gl.FLOAT, false, 0, 0
      
      $scope.gl.bindBuffer($scope.gl.ARRAY_BUFFER, $scope.sizeArrayBuffer)            # Bind point size
      attributeSize = $scope.gl.getAttribLocation($scope.pointProgram, "aPointSize")
      $scope.gl.enableVertexAttribArray attributeSize
      $scope.gl.vertexAttribPointer attributeSize, 1, $scope.gl.FLOAT, false, 0, 0
      
      $scope.gl.bindBuffer($scope.gl.ARRAY_BUFFER, $scope.colorArrayBuffer)   # Bind point color
      attributeCol = $scope.gl.getAttribLocation($scope.pointProgram, "color")
      $scope.gl.enableVertexAttribArray attributeCol     
      $scope.gl.vertexAttribPointer attributeCol, 4, $scope.gl.FLOAT, false, 0, 0
      
      # tell webgl how buffer is laid out (pairs of x,y coords)
      
      l = $scope.point_xy.length / 2

      $scope.gl.drawArrays $scope.gl.POINTS, 0, l
      
    $scope.$on 'handleMapSet', ->
      $scope.init()
      $scope.initialize_canvasLayer()
      $scope.createShaderProgram()      
      
    
    point_data                =  (city_data) ->
      point_xy                = new Float32Array(2 * city_data.length)
      point_on_screen_color   = new Float32Array(4 * city_data.length)
      point_off_screen_color  = new Float32Array(4 * city_data.length)
      point_size              = new Float32Array(    city_data.length)

      i = 0
      while i < city_data.length
        lat = city_data[i]['latitude']       
        lon = city_data[i]['longitude']
        id  = city_data[i]['id']
  
        pixel                = LatLongToPixelXY(lat, lon)
        point_xy[i * 2]      = pixel.x
        point_xy[i * 2 + 1]  = pixel.y
        point_size[i]        = 20.0

        # i + 1 
        [r, g, b] = gen_offscreen_colors(i)

        $scope.colorLookup[r + " " +  g + " " +  b] = id

        # off screen point colors (each color unique)
        point_off_screen_color[i * 4]     =  fromRgb r
        point_off_screen_color[i * 4 + 1] =  fromRgb g
        point_off_screen_color[i * 4 + 2] =  fromRgb b
        point_off_screen_color[i * 4 + 3] =  1 

        # on screen point colors (all red)
        point_on_screen_color[i * 4]     =  1
        point_on_screen_color[i * 4 + 1] =  0
        point_on_screen_color[i * 4 + 2] =  0
        point_on_screen_color[i * 4 + 3] =  1
        i++
      
      {point_off_screen_color: point_off_screen_color, point_on_screen_color: point_on_screen_color,  point_xy: point_xy, point_size: point_size}    

# Generates off screen color for data point
gen_offscreen_colors = (i) ->
  i +=1 if i == 65535 # Do not use red
  r = ((i+1) >>16) & 0xff;
  g = ((i+1) >>8) & 0xff;
  b = (i+1)  & 0xff
  [r, g, b]


Number::map = (in_min, in_max, out_min, out_max) ->
  (this - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
# Demonstrate how to register services
#In this case it is a simple value service.


# Function to convert rgb to 0-1 for webgl
fromRgb = (n) ->
  Math.ceil((parseInt(n).map(0, 255, 0, 1)) * 1000) / 1000


scaleMatrix = (matrix, scaleX, scaleY) ->
  # scaling x and y, which is just scaling first two columns of matrix
  matrix[0] *= scaleX
  matrix[1] *= scaleX
  matrix[2] *= scaleX
  matrix[3] *= scaleX
  matrix[4] *= scaleY
  matrix[5] *= scaleY
  matrix[6] *= scaleY
  matrix[7] *= scaleY

translateMatrix = (matrix, tx, ty) ->
  # translation is in last column of matrix
  matrix[12] += matrix[0] * tx + matrix[4] * ty
  matrix[13] += matrix[1] * tx + matrix[5] * ty
  matrix[14] += matrix[2] * tx + matrix[6] * ty
  matrix[15] += matrix[3] * tx + matrix[7] * ty
  
  
LatLongToPixelXY = (latitude, longitude) ->
  sinLatitude = Math.sin(latitude * pi_180)
  pixelY = (0.5 - Math.log((1 + sinLatitude) / (1 - sinLatitude)) / (pi_4)) * 256
  pixelX = ((longitude + 180) / 360) * 256
  pixel =
    x: pixelX
    y: pixelY

  pixel
pi_180 = Math.PI / 180.0
pi_4 = Math.PI * 4



