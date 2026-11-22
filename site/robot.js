// Widget clip from RobotFaceView.WidgetTransform, 384 frames at 60 fps.
(function () {
  var robot = document.querySelector(".robot");
  if (!robot) return;

  var left = robot.querySelector(".mark-left");
  var right = robot.querySelector(".mark-right");
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var PADDING = 14.88096 / 231.15084;
  var LINE = 9.920637 / 201.38893;
  var BOX = 30;
  var FRAMES = 384;

  var lookX = [
    [0, 0], [15, 0], [25.8, -2], [43.2, -2], [56.4, 2], [73.8, 2],
    [85.8, -1.6], [99, -1.6], [112.8, 0], [384, 0]
  ];
  var morph = [
    [0, 0], [128, 0], [160, 1], [288, 1], [320, 0], [384, 0]
  ];
  var jumpY = [
    [0, 0], [123, 0], [130.2, 0.7], [145.8, -6], [151.8, -6],
    [169.2, 0], [174, 0.4], [182.4, 0],
    [283.2, 0], [290.4, 0.7], [306, -6], [312, -6],
    [329.4, 0], [334.2, 0.4], [342.6, 0], [384, 0]
  ];
  var scaleXKeys = [
    [0, 1], [123, 1], [130.2, 1.02], [141, 0.99], [151.8, 1],
    [169.2, 1.03], [182.4, 1],
    [283.2, 1], [290.4, 1.02], [301.2, 0.99], [312, 1],
    [329.4, 1.03], [342.6, 1], [384, 1]
  ];
  var scaleYKeys = [
    [0, 1], [123, 1], [130.2, 0.965], [141, 1.02], [151.8, 1],
    [169.2, 0.955], [182.4, 1],
    [283.2, 1], [290.4, 0.965], [301.2, 1.02], [312, 1],
    [329.4, 0.955], [342.6, 1], [384, 1]
  ];

  // Resting eyes match the app icon. The 30-unit box is the plate inside the outline.
  var eyeLeft = { x: 7.995, y: 10.005, w: 4.158, h: 9.819, corner: 0.5 };
  var eyeRight = { x: 22.041, y: 10.005, w: 4.158, h: 9.819, corner: 0.5 };
  var value = { x: 3.5 + 6, y: 3.5 + 4.5, w: 12, h: 9, corner: 0.22 };
  var caption = { x: 3.5 + 6, y: BOX - 3.5 - 1.6, w: 12, h: 3.2, corner: 0.5 };

  // Monotone cubic: motion carries through intermediate keys, holds stay flat, no overshoot.
  function tangents(keys) {
    var slopes = [];
    for (var i = 0; i < keys.length - 1; i++) {
      slopes.push((keys[i + 1][1] - keys[i][1]) / (keys[i + 1][0] - keys[i][0]));
    }
    var result = [0];
    for (var j = 1; j < keys.length - 1; j++) {
      var d0 = slopes[j - 1];
      var d1 = slopes[j];
      if (d0 * d1 <= 0) {
        result.push(0);
      } else {
        var h0 = keys[j][0] - keys[j - 1][0];
        var h1 = keys[j + 1][0] - keys[j][0];
        result.push(3 * (h0 + h1) / ((2 * h1 + h0) / d0 + (h1 + 2 * h0) / d1));
      }
    }
    result.push(0);
    keys.tangents = result;
  }

  [lookX, morph, jumpY, scaleXKeys, scaleYKeys].forEach(tangents);

  function sample(keys, frame) {
    if (frame <= keys[0][0]) return keys[0][1];
    for (var i = 1; i < keys.length; i++) {
      var previous = keys[i - 1];
      var next = keys[i];
      if (frame <= next[0]) {
        var span = next[0] - previous[0];
        var t = (frame - previous[0]) / span;
        var t2 = t * t;
        var t3 = t2 * t;
        return (2 * t3 - 3 * t2 + 1) * previous[1]
          + (t3 - 2 * t2 + t) * span * keys.tangents[i - 1]
          + (-2 * t3 + 3 * t2) * next[1]
          + (t3 - t2) * span * keys.tangents[i];
      }
    }
    return keys[keys.length - 1][1];
  }

  function lerp(from, to, amount) {
    return from + (to - from) * amount;
  }

  function shape(from, to, amount, look) {
    return {
      x: lerp(from.x, to.x, amount) / BOX + look,
      y: lerp(from.y, to.y, amount) / BOX,
      w: lerp(from.w, to.w, amount) / BOX,
      h: lerp(from.h, to.h, amount) / BOX,
      corner: lerp(from.corner, to.corner, amount)
    };
  }

  function place(el, mark, border) {
    el.style.left = (mark.x * 100) + "%";
    el.style.top = (mark.y * 100) + "%";
    el.style.width = (mark.w * 100) + "%";
    el.style.height = (mark.h * 100) + "%";
    el.style.borderRadius = (mark.corner * Math.min(mark.w, mark.h) * border) + "px";
  }

  function frameAt(time) {
    if (reduce) return 0;
    var played = (time / 1000) * 60;
    return played % FRAMES;
  }

  var side = 0;
  var border = 0;

  function measure() {
    side = robot.clientWidth;
    border = side * (1 - PADDING * 2);
    robot.style.setProperty("--side", side + "px");
    robot.style.setProperty("--stroke", (LINE * border) + "px");
  }

  measure();
  window.addEventListener("resize", measure);

  function tick(time) {
    var frame = frameAt(time);
    var look = sample(lookX, frame) / BOX;
    var turned = sample(morph, frame);

    robot.style.transform = "translate3d(0," + (sample(jumpY, frame) / BOX * border) + "px,0) scale(" + sample(scaleXKeys, frame) + "," + sample(scaleYKeys, frame) + ")";
    place(left, shape(eyeLeft, value, turned, look), border);
    place(right, shape(eyeRight, caption, turned, look), border);

    if (!reduce) requestAnimationFrame(tick);
  }

  requestAnimationFrame(tick);
})();
