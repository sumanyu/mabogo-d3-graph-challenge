// Generated by CoffeeScript 1.6.2
(function() {
  var MabogoGraph, RadialPlacement,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  RadialPlacement = function() {
    var center, current, increment, place, placement, radialLocation, radius, setKeys, start, values;

    values = d3.map();
    increment = 20;
    radius = 200;
    center = {
      "x": 0,
      "y": 0
    };
    start = 0;
    current = start;
    radialLocation = function(center, angle, radius) {
      var x, y;

      x = center.x + radius * Math.cos(angle * Math.PI / 180);
      y = center.y + radius * Math.sin(angle * Math.PI / 180);
      return {
        "x": x,
        "y": y
      };
    };
    placement = function(key) {
      var value;

      value = values.get(key);
      if (!values.has(key)) {
        value = place(key);
      }
      return value;
    };
    place = function(key) {
      var value;

      value = radialLocation(center, current, radius);
      values.set(key, value);
      current += increment;
      return value;
    };
    setKeys = function(keys) {
      var innerKeys;

      values = d3.map();
      increment = 360 / keys.length;
      innerKeys = keys.splice(0);
      return innerKeys.forEach(function(k) {
        return place(k);
      });
    };
    placement.keys = function(_) {
      if (!arguments.length) {
        return d3.keys(values);
      }
      setKeys(_);
      return placement;
    };
    placement.center = function(_) {
      if (!arguments.length) {
        return center;
      }
      center = _;
      return placement;
    };
    placement.radius = function(_) {
      if (!arguments.length) {
        return radius;
      }
      radius = _;
      return placement;
    };
    placement.start = function(_) {
      if (!arguments.length) {
        return start;
      }
      start = _;
      current = start;
      return placement;
    };
    return placement;
  };

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
      this.force = d3.layout.force().size([this.graphWidth, this.graphHeight]).linkDistance(110).charge(-600);
      this.showcaseForce = d3.layout.force().size([this.graphWidth, this.graphHeight]).linkDistance(110).charge(-600);
      this.frozen = false;
      this.fromXY = d3.map();
      return this.showcasing = false;
    };

    MabogoGraph.prototype._updateData = function(nodes, links) {
      var circleRadius, countExtent, nodesMap;

      countExtent = d3.extent(nodes, function(d) {
        return d.links;
      });
      circleRadius = d3.scale.sqrt().range([6, 16]).domain(countExtent);
      nodes.forEach(function(node) {
        node.radius = circleRadius(node.links);
        node.x = Math.random() * this.graphWidth;
        return node.y = Math.random() * this.graphHeight;
      });
      nodesMap = this._mapNodes(nodes);
      links.forEach(function(link) {
        var _ref;

        return _ref = [link.source, link.target].map(function(l) {
          return nodesMap.get(l);
        }), link.source = _ref[0], link.target = _ref[1], _ref;
      });
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
      var _ref,
        _this = this;

      this.svg.attr('width', this.graphWidth).attr("height", this.graphHeight);
      this._addMarkers();
      _ref = ['pathG', 'nodeG', 'textG'].map(function(c) {
        return _this.svg.append("svg:g").attr("class", c);
      }), this.pathG = _ref[0], this.nodeG = _ref[1], this.textG = _ref[2];
      this._updateChart();
      return window.setTimeout(this._freezeNodes, 4000);
    };

    MabogoGraph.prototype._updateChart = function() {
      this._updateLinks();
      this._updateNodes();
      return this._updateText();
    };

    MabogoGraph.prototype._addMarkers = function() {
      this.markers = this.svg.append("svg:defs").selectAll("marker").data(["friend", "acquaintance"]);
      return this.markers.enter().append("svg:marker").attr("id", String).attr("viewBox", "0 -5 10 10").attr("refX", 15).attr("refY", -1.5).attr("markerWidth", 10).attr("markerHeight", 10).attr("orient", "auto").append("svg:path").attr("d", "M0,-5L10,0L0,5");
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
      }).attr("x", function(d) {
        return d.x;
      }).attr("y", function(d) {
        return d.y;
      }).style("fill", function(d) {
        return _this.colorScale(d.type);
      }).on("click", function(d, i) {
        if (_this.frozen) {
          return _this._showcaseSubnetwork(d);
        }
      });
      this._addOnHover();
      return this.node.exit().remove();
    };

    MabogoGraph.prototype._differenceOfMapAB = function(A, B) {
      var retMap;

      retMap = d3.map();
      A.keys().forEach(function(key) {
        if (!B.has(key)) {
          return retMap.set(key, A.get(key));
        }
      });
      return retMap;
    };

    MabogoGraph.prototype._showcaseSubnetwork = function(center) {
      var fromXY, radialMap, restoreXY, toXY, _ref,
        _this = this;

      if (center.id === ((_ref = this.centerNode) != null ? _ref.id : void 0)) {
        this._translateGraph(this.fromXY);
        this.fromXY = d3.map();
        this.centerNode = null;
        this._restoreOpacity();
        return this._addOnHover();
      } else {
        this.showcasing = true;
        this.showcasedNodes = [];
        this.centerNode = center;
        toXY = d3.map();
        fromXY = d3.map();
        this._setFromXY(fromXY, center);
        toXY.set(center.id, {
          x: this.graphWidth / 2,
          y: this.graphHeight / 2
        });
        this.force.links().forEach(function(link) {
          var node, _ref1;

          if ((_ref1 = center.id) === link.source.id || _ref1 === link.target.id) {
            node = center.id === link.source.id ? link.target : link.source;
            _this._setFromXY(fromXY, node);
            return _this.showcasedNodes.push(node);
          }
        });
        radialMap = RadialPlacement().center(toXY.get(center.id)).keys(this.showcasedNodes.map(function(node) {
          return node.id;
        }));
        this.showcasedNodes.forEach(function(node) {
          return toXY.set(node.id, radialMap(node.id));
        });
        restoreXY = this._differenceOfMapAB(this.fromXY, fromXY);
        this._translateGraph(toXY);
        this._translateGraph(restoreXY);
        this._highlightShowcased(toXY);
        this._removeOnHover();
        return this.fromXY = fromXY;
      }
    };

    MabogoGraph.prototype._addOnHover = function() {
      var context;

      context = this;
      return this.node.on("mouseover", function(d, i) {
        return context._showDetails(context, this, d);
      }).on("mouseout", function(d, i) {
        return context._hideDetails(context, this, d);
      });
    };

    MabogoGraph.prototype._removeOnHover = function() {
      var context;

      context = this;
      return this.node.on("mouseover", function(d, i) {
        if (__indexOf.call(context.showcasedNodes, d) >= 0) {
          return context._showPreviewDetails(context, this, d);
        } else {
          return null;
        }
      }).on("mouseout", function(d, i) {
        if (__indexOf.call(context.showcasedNodes, d) >= 0) {
          return context._hidePreviewDetails(context, this, d);
        } else {
          return null;
        }
      });
    };

    MabogoGraph.prototype._showPreviewDetails = function(context, obj, d) {
      return context.path.attr("stroke-opacity", function(l) {
        var cond1, cond2;

        cond1 = l.source === d && l.target === context.centerNode;
        cond2 = l.source === context.centerNode && l.target === d;
        if (cond1 || cond2) {
          return 1.0;
        } else {
          return d3.select(this).attr("stroke-opacity");
        }
      });
    };

    MabogoGraph.prototype._hidePreviewDetails = function(context, obj, d) {
      return context.path.attr("stroke-opacity", function(l) {
        console.log(parseFloat(d3.select(this).attr("stroke-opacity")) === 1.0);
        if (parseFloat(d3.select(this).attr("stroke-opacity")) === 1.0) {
          return 0.5;
        } else {
          return d3.select(this).attr("stroke-opacity");
        }
      });
    };

    MabogoGraph.prototype._highlightShowcased = function(toXY) {
      var _this = this;

      [this.node, this.text].forEach(function(selector) {
        return selector.attr("opacity", function(d) {
          if (toXY.has(d.id) || d === _this.centerNode) {
            return 1.0;
          } else {
            return 0.05;
          }
        });
      });
      return this.path.attr("stroke-opacity", function(l) {
        if (l.source === _this.centerNode || l.target === _this.centerNode) {
          return .50;
        } else {
          return 0.0;
        }
      });
    };

    MabogoGraph.prototype._restoreOpacity = function() {
      var _this = this;

      console.log("Restoring opacity");
      [this.node, this.text].forEach(function(selector) {
        return selector.attr("opacity", 1.0);
      });
      return this.path.attr("stroke-opacity", 0.5);
    };

    MabogoGraph.prototype._translateGraph = function(mapXY) {
      var _this = this;

      [this.node, this.text].forEach(function(selector) {
        return selector.transition().attr("transform", function(d) {
          var _ref, _ref1, _ref2, _ref3;

          d.x = (_ref = (_ref1 = mapXY.get(d.id)) != null ? _ref1.x : void 0) != null ? _ref : d.x;
          d.y = (_ref2 = (_ref3 = mapXY.get(d.id)) != null ? _ref3.y : void 0) != null ? _ref2 : d.y;
          return "translate(" + d.x + "," + d.y + ")";
        });
      });
      return this.path.transition().attr("d", function(d) {
        var dr, dx, dy;

        dx = d.target.x - d.source.x;
        dy = d.target.y - d.source.y;
        dr = Math.sqrt(dx * dx + dy * dy);
        return "M" + d.source.x + "," + d.source.y + "A" + dr + "," + dr + " 0 0,1 " + d.target.x + "," + d.target.y;
      });
    };

    MabogoGraph.prototype._setFromXY = function(fromXY, node) {
      var val, _ref;

      val = (_ref = this.fromXY.get(node.id)) != null ? _ref : {
        x: node.x,
        y: node.y
      };
      return fromXY.set(node.id, val);
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
      var g;

      this.text = this.textG.selectAll("g").data(this.force.nodes());
      g = this.text.enter().append("svg:g");
      g.append("svg:text").attr("x", 8).attr("y", ".31em").attr("class", "shadow").text(function(d) {
        return d.name;
      });
      g.append("svg:text").attr("x", 8).attr("y", ".31em").text(function(d) {
        return d.name;
      });
      return this.text.exit().remove();
    };

    MabogoGraph.prototype._freezeNodes = function() {
      if (!this.frozen) {
        this.force.nodes().forEach(function(node) {
          return node.fixed = true;
        });
        return this.frozen = true;
      }
    };

    MabogoGraph.prototype._updateTick = function() {
      if (!this.showcasing) {
        this.path.attr("d", function(d) {
          var dr, dx, dy;

          dx = d.target.x - d.source.x;
          dy = d.target.y - d.source.y;
          dr = Math.sqrt(dx * dx + dy * dy);
          return "M" + d.source.x + "," + d.source.y + "A" + dr + "," + dr + " 0 0,1 " + d.target.x + "," + d.target.y;
        });
        this.node.attr("transform", function(d) {
          return "translate(" + d.x + "," + d.y + ")";
        });
        return this.text.attr("transform", function(d) {
          return "translate(" + d.x + "," + d.y + ")";
        });
      }
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
