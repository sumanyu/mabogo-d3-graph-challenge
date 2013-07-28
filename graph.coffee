class MabogoGraph
  constructor: (@body) ->
    # Input validations, event hooks, etc.

    @vis = @body.find("svg#mobogo-graph")
    @selection = d3.select(@vis[0])

    @_setup()

  _setup: ->
    # size of the drawing area inside the svg's to make
    # the bar charts
    @graphWidth = 800
    @graphHeight = 400

    @margin = 
      top: 40
      bottom: 40
      left: 40
      right: 40

    # using an ordinal scale for X as our
    # data is categorical (the names of axis label)
    @xScale = d3.scale.ordinal()
      .rangeRoundBands [0, @graphWidth - @margin.left - @margin.right], 0.14 #last arg: higher value -> thinner bars

    colors = @vis.data("colors") || ['#7b9bb4', '#e9d7c3', '#b6c477', '#f8a363', '#c56767'] #default to CNN colors

    # colors for the stacked bar
    @colorScale = d3.scale.ordinal().range(colors)

    # yPadding is removed to make room for country names
    @yScale = d3.scale.linear()
      .range [0, @graphHeight - @margin.top - @margin.bottom]

    @inverted_yScale = d3.scale.linear()
      .range [@graphHeight - @margin.top - @margin.bottom, 0]

    # animation variables
    @animDuration = 1000

    # controls padding between axis line, perpendicular ticks and labels
    @tick_padding =
      x: 11
      y: 8

    d3.json "nodes.json", (err, nodes) =>
      @nodes = nodes

      d3.json "edges.json", (err, edges) =>
        @edges = edges
        @drawChart()

  _setScales: ->
    do ( yMax = 30000 ) =>

      # this scale is expanded past its max to provide some white space
      # on the top of the bars
      @yScale.domain [0, yMax + 200]
      @inverted_yScale.domain [0, yMax + 200]

    @xScale.domain d3.range(@data[0].length)

$ ->
  $("#mobogo-graph-container").each -> new MabogoGraph($(@))