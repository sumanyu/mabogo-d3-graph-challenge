class MabogoGraph
  constructor: (@body, data) ->
    # Input validations, event hooks, etc.

    @vis = @body.find("svg#mobogo-graph")
    @svg = d3.select(@vis[0])

    @_setup()
    @_updateData(data.nodes, data.links)
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
              .charge(-600) # Lower -> higher network distance 

  # Nodes expect the following fields
  # Randomly assigned values if not supplied
    # index - the zero-based index of the node within the nodes array.
    # x - the x-coordinate of the current node position.
    # y - the y-coordinate of the current node position.
    # px - the x-coordinate of the previous node position.
    # py - the y-coordinate of the previous node position.
    # fixed - a boolean indicating whether node position is locked.
    # weight - the node weight; the number of associated links.

  _updateData: (nodes, links) ->
    # Get max # of links
    console.log nodes, links
    countExtent = d3.extent(nodes, (d) -> d.links)
    circleRadius = d3.scale.sqrt().range([6, 16]).domain(countExtent)

    nodes.forEach (node) ->
      # Size radius according to the # of links
      node.radius = circleRadius(node.links)

    # map of id -> node
    nodesMap = @_mapNodes(nodes)

    links.forEach (link) ->
      link.source = nodesMap.get(link.source)
      link.target = nodesMap.get(link.target)

    console.log nodes, links

    @force.nodes(nodes)
      .links(links)
      .on("tick", @_updateTick).start()

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

    # Draw links before nodes so nodes can sit on top
    @pathG = @svg.append("svg:g")
              .attr("class", "pathG")

    @nodeG = @svg.append("svg:g")
              .attr("class", "nodeG")    

    @textG = @svg.append("svg:g")
              .attr("class", "textG")

    @_updateChart()

    window.setTimeout(@_freezeNodes, 5000)

  _updateChart: ->
    @_updateLinks()
    @_updateNodes()
    @_updateText()

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
  _updateLinks: ->
    @path = @pathG.selectAll("path.link")
              .data(@force.links())

    @path.enter().append("svg:path")
      .attr("class", (d) -> "link #{d.type}")
      .attr("stroke-opacity", 0.5)
      .attr("marker-end", (d) -> "url(##{d.type})")

    @path.exit().remove()

  _updateNodes: ->
    context = @
    @node = @nodeG.selectAll("circle.node")
              .data(@force.nodes())

    @node.enter().append("svg:circle")
      .attr("class", "node")
      .attr("r", (d)-> d.radius)
      .style("fill", (d) => @colorScale(d.type))
      .call(@force.drag)
      .on("mouseover", (d, i) -> context._showDetails(context, @, d))
      .on("mouseout", (d, i) -> context._hideDetails(context, @, d))

    @node.exit().remove()

  _showDetails: (context, obj, d) ->
    context.path.attr("stroke-opacity", (l) -> 
      if l.source == d or l.target == d then 1.0 else 0.5)

    d3.select(obj).style("fill", "#ddd")

  _hideDetails: (context, obj, d) ->
    context.path.attr("stroke-opacity", 0.5)

    d3.select(obj).style("fill", @colorScale(d.type))

  _updateText: ->
    @text = @textG.selectAll("g")
              .data(@force.nodes())
            
    g = @text.enter().append("svg:g")

    g.append("svg:text")
        .attr("x", 8)
        .attr("y", ".31em")
        .attr("class", "shadow")
        .text((d) -> d.name)

    g.append("svg:text")
        .attr("x", 8)
        .attr("y", ".31em")
        .text((d) -> d.name)

    @text.exit().remove()

  _freezeNodes: =>
    nodes = @force.nodes()
    links = @force.links()

    nodes.forEach (node) ->
      node.fixed = true

    links.forEach (link) ->
      link.source = link.source.id
      link.target = link.target.id

    @_updateData(nodes, links)

    @_updateChart()

  _updateTick: =>
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