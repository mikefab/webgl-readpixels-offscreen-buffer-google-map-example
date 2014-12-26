An example of Webgl picking data points with readPixels from a google map using an offscreen buffer. 

References:
- Pedro Sousa's blog on Displaying WebGL data on Google Maps
- Google I/O 2013 - Google Maps + HTML5 + Spatial Data Visualization: A Love Story
- WebGL Beginner's Guide

Mouseover a point to see the city name.

Live demo: http://codepen.io/mikefab/full/yhEfu/

Server: 

# Haml Coffee Sinatra

This is an example [Sinatra](https://github.com/sinatra/sinatra) application based on the
[Sinatra Asset Pipeline](https://github.com/petebrowne/sinatra-asset-pipeline) example application  to show the
usage of [Haml Coffee Assets](https://github.com/netzpirat/haml_coffee_assets).

## Run the app

Clone the app, switch to the directory and run:

```
bundle install
bundle exec rackup
```

Now visit [http://http://localhost:9292/](http://localhost:9292/) top see it in action.

## Compile client side templates

This example uses [Guard](https://github.com/guard/guard) with
[Guard Sprockets2](https://github.com/stevehodgkiss/guard-sprockets2) to compile the client side templates.

Run guard with:

```
bundle exec guard
```
