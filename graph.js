// Generated by CoffeeScript 1.6.2
(function() {
  var MabogoGraph,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  MabogoGraph = (function() {
    function MabogoGraph(body, data) {
      this.body = body;
      this._updateTick = __bind(this._updateTick, this);
      this._freezeNodes = __bind(this._freezeNodes, this);
      this.vis = this.body.find("svg#mobogo-graph");
      this.svg = d3.select(this.vis[0]);
      this._setup();
      this._updateData(data.nodes, data.links);
      this._drawChart();
    }

    MabogoGraph.prototype._setup = function() {
      this.graphWidth = 800;
      this.graphHeight = 600;
      this.colorScale = d3.scale.category20();
      return this.force = d3.layout.force().size([this.graphWidth, this.graphHeight]).linkDistance(110).charge(-600);
    };

    MabogoGraph.prototype._updateData = function(nodes, links) {
      var circleRadius, countExtent, nodesMap;

      console.log(nodes, links);
      countExtent = d3.extent(nodes, function(d) {
        return d.links;
      });
      circleRadius = d3.scale.sqrt().range([6, 16]).domain(countExtent);
      nodes.forEach(function(node) {
        return node.radius = circleRadius(node.links);
      });
      nodesMap = this._mapNodes(nodes);
      links.forEach(function(link) {
        link.source = nodesMap.get(link.source);
        return link.target = nodesMap.get(link.target);
      });
      console.log(nodes, links);
      return this.force.nodes(nodes).links(links).on("tick", this._updateTick).start();
    };

    MabogoGraph.prototype._mapNodes = function(nodes) {
      var nodesMap;

      nodesMap = d3.map();
      nodes.forEach(function(node) {
        return nodesMap.set(node.id, node);
      });
      return nodesMap;
    };

    MabogoGraph.prototype._drawChart = function() {
      this.svg.attr('width', this.graphWidth).attr("height", this.graphHeight);
      this._addMarkers();
      this.pathG = this.svg.append("svg:g").attr("class", "pathG");
      this.nodeG = this.svg.append("svg:g").attr("class", "nodeG");
      this.textG = this.svg.append("svg:g").attr("class", "textG");
      this._updateChart();
      return window.setTimeout(this._freezeNodes, 5000);
    };

    MabogoGraph.prototype._updateChart = function() {
      this._updateLinks();
      this._updateNodes();
      return this._updateText();
    };

    MabogoGraph.prototype._addMarkers = function() {
      return this.svg.append("svg:defs").selectAll("marker").data(["friend", "acquaintance"]).enter().append("svg:marker").attr("id", String).attr("viewBox", "0 -5 10 10").attr("refX", 15).attr("refY", -1.5).attr("markerWidth", 10).attr("markerHeight", 10).attr("orient", "auto").append("svg:path").attr("d", "M0,-5L10,0L0,5");
    };

    MabogoGraph.prototype._updateLinks = function() {
      this.path = this.pathG.selectAll("path.link").data(this.force.links());
      this.path.enter().append("svg:path").attr("class", function(d) {
        return "link " + d.type;
      }).attr("stroke-opacity", 0.5).attr("marker-end", function(d) {
        return "url(#" + d.type + ")";
      });
      return this.path.exit().remove();
    };

    MabogoGraph.prototype._updateNodes = function() {
      var context,
        _this = this;

      context = this;
      this.node = this.nodeG.selectAll("circle.node").data(this.force.nodes());
      this.node.enter().append("svg:circle").attr("class", "node").attr("r", function(d) {
        return d.radius;
      }).style("fill", function(d) {
        return _this.colorScale(d.type);
      }).call(this.force.drag).on("mouseover", function(d, i) {
        return context._showDetails(context, this, d);
      }).on("mouseout", function(d, i) {
        return context._hideDetails(context, this, d);
      });
      return this.node.exit().remove();
    };

    MabogoGraph.prototype._showDetails = function(context, obj, d) {
      context.path.attr("stroke-opacity", function(l) {
        if (l.source === d || l.target === d) {
          return 1.0;
        } else {
          return 0.5;
        }
      });
      return d3.select(obj).style("fill", "#ddd");
    };

    MabogoGraph.prototype._hideDetails = function(context, obj, d) {
      context.path.attr("stroke-opacity", 0.5);
      return d3.select(obj).style("fill", this.colorScale(d.type));
    };

    MabogoGraph.prototype._updateText = function() {
      this.text = this.textG.selectAll("g").data(this.force.nodes());
      return this.text.enter().append("svg:g").append("svg:text").attr("x", 8).attr("y", ".31em").attr("class", "shadow").text(function(d) {
        return d.name;
      });
    };

    MabogoGraph.prototype._freezeNodes = function() {
      var links, nodes;

      nodes = this.force.nodes();
      links = this.force.links();
      nodes.forEach(function(node) {
        return node.fixed = true;
      });
      links.forEach(function(link) {
        link.source = link.source.id;
        return link.target = link.target.id;
      });
      this._updateData(nodes, links);
      return this._updateChart();
    };

    MabogoGraph.prototype._updateTick = function() {
      this.path.attr("d", function(d) {
        var _this = this;

        return (function(dx, dy) {
          var dr;

          dr = Math.sqrt(dx * dx + dy * dy);
          return "M" + d.source.x + "," + d.source.y + "A" + dr + "," + dr + " 0 0,1 " + d.target.x + "," + d.target.y;
        })(d.target.x - d.source.x, d.target.y - d.source.y);
      });
      this.node.attr("transform", function(d) {
        return "translate(" + d.x + "," + d.y + ")";
      });
      return this.text.attr("transform", function(d) {
        return "translate(" + d.x + "," + d.y + ")";
      });
    };

    return MabogoGraph;

  })();

  $(function() {
    return $("#mobogo-graph-container").each(function() {
      var _this = this;

      return d3.json("data.json", function(err, data) {
        return new MabogoGraph($(_this), data);
      });
    });
  });

}).call(this);
