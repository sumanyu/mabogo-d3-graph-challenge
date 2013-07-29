class MabogoGraph
  constructor: (@body, data) ->
    # Input validations, event hooks, etc.

    @vis = @body.find("svg#mobogo-graph")
    @svg = d3.select(@vis[0])

    @_setup()
    @_setupData(data)
    @_drawChart()

  _setup: ->
    # size of the drawing area inside the svg's to make
    # the bar charts
    @graphWidth = 800
    @graphHeight = 600
        
    # colors 
    @colorScale = d3.scale.category20();

    @force = d3.layout.force()
              .size([@graphWidth, @graphHeight])
              .linkDistance(110) # Higher # -> higher link distance
              .charge(-500) # Lower -> higher network distance 

  # Nodes expect the following fields
  # Randomly assigned values if not supplied
    # index - the zero-based index of the node within the nodes array.
    # x - the x-coordinate of the current node position.
    # y - the y-coordinate of the current node position.
    # px - the x-coordinate of the previous node position.
    # py - the y-coordinate of the previous node position.
    # fixed - a boolean indicating whether node position is locked.
    # weight - the node weight; the number of associated links.

  _setupData: (data) ->
    # Get max # of links
    countExtent = d3.extent(data.nodes, (d) -> d.links)
    circleRadius = d3.scale.sqrt().range([6, 16]).domain(countExtent)

    data.nodes.forEach (node) ->
      # Size radius according to the # of links
      node.radius = circleRadius(node.links)

    # map of id -> node
    nodesMap = @_mapNodes(data.nodes)

    data.links.forEach (link) ->
      link.source = nodesMap.get(link.source)
      link.target = nodesMap.get(link.target)

    @force.nodes(data.nodes)
      .links(data.links)
      .on("tick", @_updateGraph).start()

  # Maps node.id -> node
  _mapNodes: (nodes) ->
    nodesMap = d3.map()
    nodes.forEach (node) ->
      nodesMap.set(node.id, node)
    nodesMap

  _drawChart: ->
    @svg
      .attr('width', @graphWidth)
      .attr("height", @graphHeight)

    @_addMarkers()
    @_addPaths()
    @_addNodes()
    @_addText()

  # Adds arrow tips
  _addMarkers: ->
    @svg.append("svg:defs").selectAll("marker")
        .data(["friend", "acquaintance"])
      .enter().append("svg:marker")    
        .attr("id", String)
        .attr("viewBox", "0 -5 10 10")
        .attr("refX", 15)
        .attr("refY", -1.5)
        .attr("markerWidth", 10)
        .attr("markerHeight", 10)
        .attr("orient", "auto")
      .append("svg:path")
        .attr("d", "M0,-5L10,0L0,5")

  # Draw path from source to target
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
                  .attr("r", (d)-> d.radius)
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
  $("#mobogo-graph-container").each ->
    d3.json "data.json", (err, data) =>
      new MabogoGraph($(@), data)