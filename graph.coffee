class MabogoGraph
  constructor: (@body) ->
    # Input validations, event hooks, etc.

    @vis = @body.find("svg#mobogo-graph")
    @svg = d3.select(@vis[0])

    @_setup()

  _setup: ->
    # size of the drawing area inside the svg's to make
    # the bar charts
    @graphWidth = 800
    @graphHeight = 600

    # colors 
    @colorScale = d3.scale.category20();

    @force = d3.layout.force()
              .size([@graphWidth, @graphHeight])
              .linkDistance(70)
              .charge(-300)

    d3.json "nodes.json", (err, nodes) =>
      d3.json "edges.json", (err, edges) =>

        @force.nodes(nodes)
            .links(edges)
            .on("tick", @_updateGraph).start()
        @_drawChart()

  _drawChart: ->
    @svg
      .attr('width', @graphWidth)
      .attr("height", @graphHeight)

    @_addMarkers()
    @_addPaths()
    @_addNodes()
    @_addText()

  _addMarkers: ->
    @svg.append("svg:defs").selectAll("marker")
        .data(["friend", "acquaintance"])
      .enter().append("svg:marker")    
        .attr("id", String)
        .attr("viewBox", "0 -5 10 10")
        .attr("refX", 15)
        .attr("refY", -1.5)
        .attr("markerWidth", 6)
        .attr("markerHeight", 6)
        .attr("orient", "auto")
      .append("svg:path")
        .attr("d", "M0,-5L10,0L0,5")

  _addPaths: ->
    @path = @svg.append("svg:g").selectAll("path")
        .data(@force.links())
      .enter().append("svg:path")
        .attr("class", (d) -> "link #{d.type}")
        .attr("marker-end", (d) -> "url(##{d.type})")

  _addNodes: ->
    @node = @svg.append("svg:g").selectAll("circle")
                  .data(@force.nodes())
                .enter().append("svg:circle")
                  .attr("r", 6)
                  .style("fill", (d) => @colorScale(d.type))
                  .call(@force.drag)

  _addText: ->
    @text = @svg.append("svg:g").selectAll("g")
              .data(@force.nodes())
            .enter().append("svg:g")

    @text.append("svg:text")
        .attr("x", 8)
        .attr("y", ".31em")
        .attr("class", "shadow")
        .text((d) -> d.name)

    @text.append("svg:text")
        .attr("x", 8)
        .attr("y", ".31em")
        .text((d) -> d.name)

  _updateGraph: =>
    @path.attr("d", (d) ->
      do (dx = d.target.x - d.source.x, dy = d.target.y - d.source.y) =>
        dr = Math.sqrt(dx * dx + dy * dy)
        "M#{d.source.x},#{d.source.y}A#{dr},#{dr} 0 0,1 #{d.target.x},#{d.target.y}"
    )

    @node.attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")") 
    @text.attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")
$ ->
  $("#mobogo-graph-container").each -> new MabogoGraph($(@))