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
  start = 0
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

    # Keep track of node's base XY positions
    @fromXY = d3.map()

    @showcasing = false

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
    @markers = @svg.append("svg:defs").selectAll("marker")
        .data(["friend", "acquaintance"])

    @markers.enter().append("svg:marker")    
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
      .attr("x", (d) -> d.x)
      .attr("y", (d) -> d.y)
      .style("fill", (d) => @colorScale(d.type))
      .on("click", (d, i) => @_showcaseSubnetwork(d) if @frozen )

    @_addOnHover()

    @node.exit().remove()

  # Returns a map of A - B
  _differenceOfMapAB: (A, B) ->
    retMap = d3.map()
    A.keys().forEach (key) ->
      retMap.set(key, A.get(key)) unless B.has(key)

    retMap

  # Where the magic happens
  _showcaseSubnetwork: (center) ->

    # Restore all if old center node is clicked
    if center.id is @centerNode?.id
      @_translateGraph(@fromXY)
      @fromXY = d3.map()
      @centerNode = null
      @_restoreOpacity()
      @_addOnHover()
    else
      @showcasing = true
      @showcasedNodes = []
      @centerNode = center

      toXY = d3.map()
      fromXY = d3.map()

      # Set centerNode
      @_setFromXY(fromXY, center)
      toXY.set(center.id, {x: @graphWidth/2, y: @graphHeight/2})

      # Add all associated 1 degree nodes
      @force.links().forEach (link) =>
        if center.id in [link.source.id, link.target.id]
          node = if center.id is link.source.id then link.target else link.source
          @_setFromXY(fromXY, node)
          @showcasedNodes.push node

      # Set polar x, y for each node
      radialMap = RadialPlacement()
                    .center(toXY.get(center.id))
                    .keys(@showcasedNodes.map (node) -> node.id)

      @showcasedNodes.forEach (node) ->
        toXY.set(node.id, radialMap(node.id))

      # All nodes that exist in @fromXY but not in fromXY
      # These nodes will be restored to original XY
      restoreXY = @_differenceOfMapAB(@fromXY, fromXY)

      # Translate new nodes
      @_translateGraph(toXY)

      # Restore old nodes
      @_translateGraph(restoreXY)

      # Change node, text, path's opacity
      @_highlightShowcased(toXY)
      @_removeOnHover()

      @fromXY = fromXY

  _addOnHover: ->
    context = @
    @node
      .on("mouseover", (d, i) -> context._showDetails(context, @, d))
      .on("mouseout", (d, i) -> context._hideDetails(context, @, d))

  _removeOnHover: ->
    context = @
    @node
      .on("mouseover", (d, i) -> 
        if d in context.showcasedNodes then context._showPreviewDetails(context, @, d) else null)
      .on("mouseout", (d, i) -> 
        if d in context.showcasedNodes then context._hidePreviewDetails(context, @, d) else null)

  _showPreviewDetails: (context, obj, d) ->
    context.path.attr("stroke-opacity", (l) ->
      cond1 = l.source is d and l.target is context.centerNode
      cond2 = l.source is context.centerNode and l.target is d

      if cond1 or cond2 then 1.0 else d3.select(@).attr("stroke-opacity"))

  _hidePreviewDetails: (context, obj, d) ->
    context.path.attr("stroke-opacity", (l) ->
      console.log parseFloat(d3.select(@).attr("stroke-opacity")) is 1.0
      if parseFloat(d3.select(@).attr("stroke-opacity")) is 1.0 then 0.5 else d3.select(@).attr("stroke-opacity"))

  _highlightShowcased: (toXY) ->
    [@node, @text].forEach (selector) =>
      selector.attr("opacity", (d) => 
        if toXY.has(d.id) or d is @centerNode then 1.0 else 0.05)

    @path.attr("stroke-opacity", (l) => 
      if l.source == @centerNode or l.target == @centerNode then .50 else 0.0)

  _restoreOpacity: ->
    console.log "Restoring opacity"
    [@node, @text].forEach (selector) =>
      selector.attr("opacity", 1.0)

    @path.attr("stroke-opacity", 0.5)

  _translateGraph: (mapXY) ->
    # Translate nodes, text and path
    [@node, @text].forEach (selector) =>
      selector.transition()
      .attr("transform", (d) => 
          d.x = mapXY.get(d.id)?.x ? d.x
          d.y = mapXY.get(d.id)?.y ? d.y
          "translate(" + d.x + "," + d.y + ")" )

    @path.transition()
      .attr("d", (d) =>
          dx = d.target.x - d.source.x
          dy = d.target.y - d.source.y

          dr = Math.sqrt(dx * dx + dy * dy)
          "M#{d.source.x},#{d.source.y}A#{dr},#{dr} 0 0,1 #{d.target.x},#{d.target.y}" )

  _setFromXY: (fromXY, node) ->
    val = @fromXY.get(node.id) ? {x: node.x, y: node.y}
    fromXY.set( node.id, val )

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
    unless @showcasing
      @path.attr("d", (d) ->
        dx = d.target.x - d.source.x
        dy = d.target.y - d.source.y
        dr = Math.sqrt(dx * dx + dy * dy)
        "M#{d.source.x},#{d.source.y}A#{dr},#{dr} 0 0,1 #{d.target.x},#{d.target.y}"
      )

      @node.attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")") 
      @text.attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

$ ->
  $("#mobogo-graph-container").each ->
    d3.json "data.json", (err, data) =>
      new MabogoGraph($(@), data)