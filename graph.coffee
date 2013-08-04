# Help with the placement of nodes
RadialPlacement = () ->
  # stores the key -> location values
  values = d3.map()
  # how much to separate each location by
  increment = 20
  # how large to make the layout
  radius = 200
  # where the center of the layout should be
  center = {"x":0, "y":0}
  # what angle to start at
  start = -120
  current = start

  # Given an center point, angle, and radius length,
  # return a radial position for that angle
  radialLocation = (center, angle, radius) ->
    x = (center.x + radius * Math.cos(angle * Math.PI / 180))
    y = (center.y + radius * Math.sin(angle * Math.PI / 180))
    {"x":x,"y":y}

  # Main entry point for RadialPlacement
  # Returns location for a particular key,
  # creating a new location if necessary.
  placement = (key) ->
    value = values.get(key)
    if !values.has(key)
      value = place(key)
    value

  # Gets a new location for input key
  place = (key) ->
    value = radialLocation(center, current, radius)
    values.set(key,value)
    current += increment
    value

  # Given a set of keys, set x,y
  # Expects radius, center to be set.
  setKeys = (keys) ->
    # start with an empty values
    values = d3.map()

    increment = 360 / keys.length

    # Shallow copy
    innerKeys = keys.splice(0)

    # set locations inside circle
    innerKeys.forEach (k) -> place(k)

  placement.keys = (_) ->
    if !arguments.length
      return d3.keys(values)
    setKeys(_)
    placement

  placement.center = (_) ->
    if !arguments.length
      return center
    center = _
    placement

  placement.radius = (_) ->
    if !arguments.length
      return radius
    radius = _
    placement

  placement.start = (_) ->
    if !arguments.length
      return start
    start = _
    current = start
    placement

  return placement

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

    @showcaseForce = d3.layout.force()
              .size([@graphWidth, @graphHeight])
              .linkDistance(110) # Higher # -> higher link distance
              .charge(-600) # Lower -> higher network distance

    # Keep track of whether nodes are frozen
    @frozen = false

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
    countExtent = d3.extent(nodes, (d) -> d.links)
    circleRadius = d3.scale.sqrt().range([6, 16]).domain(countExtent)

    nodes.forEach (node) ->
      # Size radius according to the # of links
      node.radius = circleRadius(node.links)
      node.x = Math.random()*@graphWidth
      node.y = Math.random()*@graphHeight

    # map of id -> node
    nodesMap = @_mapNodes(nodes)

    links.forEach (link) ->
      [link.source, link.target] = [link.source, link.target].map (l) -> nodesMap.get(l)

    @force.nodes(nodes)
      .links(links)
      .on("tick", @_updateTick).start()

  # Maps node.id -> node
  _mapNodes: (nodes) ->
    nodesMap = d3.map()
    nodes.forEach (node) -> nodesMap.set(node.id, node)
    nodesMap

  _drawChart: ->
    @svg
      .attr('width', @graphWidth)
      .attr("height", @graphHeight)

    @_addMarkers()

    # Draw links before nodes so nodes can sit on top
    [@pathG, @nodeG, @textG] = ['pathG', 'nodeG', 'textG'].map (c) => 
                                @svg.append("svg:g")
                                  .attr("class", c)

    @_updateChart()

    window.setTimeout(@_freezeNodes, 4000)

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
      .on("click", (d, i) => @_showcaseSubnetwork(d) if @frozen)

    @node.exit().remove()

  _showcaseSubnetwork: (d) ->
    # Gather 1 degree separated nodes and links
    @showcase = 
      nodes: []
      links: []
      centerNode: null

    # Set centerNode to the clicked item
    @force.nodes().forEach (node) =>
      if d.id is node.id
        center = node
        [center.prev_x, center.prev_y] = [center.x, center.y]
        [center.x, center.y] = [@graphWidth/2, @graphHeight/2]

        @showcase.centerNode = center

    # Add all associated 1 degree nodes to showcase nodes
    @force.links().forEach (link) =>
      if d.id in [link.source.id, link.target.id]

        @showcase.links.push link

        node = if d.id is link.source.id then link.target else link.source
        [node.prev_x, node.prev_y] = [node.x, node.y]
        @showcase.nodes.push node

    radialMap = RadialPlacement().center({"x":@showcase.centerNode.x,"y":@showcase.centerNode.y})
                  .keys(@showcase.nodes.map (node) -> node.id)

    @showcase.nodes.forEach (node) ->
      [node.x, node.y] = [radialMap(node.id).x, radialMap(node.id).y]

    # Update links' source and target now that radial x,y are set for all showcase nodes
    nodesMap = @_mapNodes(@showcase.nodes)
    nodesMap.set(@showcase.centerNode.id, @showcase.centerNode)

    @showcase.links.forEach (link) ->
      [link.source, link.target] = [link.source.id, link.target.id].map (l) -> nodesMap.get(l)

    console.log @showcase

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
    unless @frozen
      @force.nodes().forEach (node) -> node.fixed = true
      @frozen = true

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