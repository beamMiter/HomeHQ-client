#version 460 core

#include <flutter/runtime_effect.glsl>

// The air an air conditioner blows: smooth streamlines that leave the louver
// and flare out into the room, with brighter rushes running down each one and
// a soft mist round them, all spreading, slowing and fading as they go.
//
// Everything is in the painter's own coordinates. The along-the-flow
// coordinate scrolls with uFlow, and the noise repeats every 64 units of it
// (every multiplier of uFlow below is a whole number), so the painter can wrap
// uFlow at 64 without the air jumping.
//
// How far the air fans out, and how far it gets before it fades, are carried
// with it: each is given at 0, 1/3, 2/3 and all of the trip out, so when the
// louver turns, the change runs out along the air instead of turning it all
// at once (the painter's AirKnots is the same curve).

uniform vec4 uOutlet; // centre x, top y, half width at the louver, reach
uniform vec4 uSpread; // how far it fans out, along the trip
uniform vec4 uLength; // how much of the reach it gets before it fades, along it
uniform vec3 uShape;  // bend, strength, front (how far the air has got)
uniform vec3 uNear;   // colour at the louver
uniform vec3 uFar;    // colour where it fades
uniform vec3 uWarm;   // auto: the warm air turning over the cool
uniform float uFlow;
uniform float uMode;  // 0 cool, 1 heat, 2 dry, 3 fan, 4 auto

out vec4 fragColor;

// The smooth curve through four values at 0, 1/3, 2/3 and 1 of the trip.
float knots(vec4 k, float s) {
  float u = clamp(s, 0.0, 1.0) * 3.0;
  vec4 w = vec4(
    -(u - 1.0) * (u - 2.0) * (u - 3.0) / 6.0,
    u * (u - 2.0) * (u - 3.0) / 2.0,
    -u * (u - 1.0) * (u - 3.0) / 2.0,
    u * (u - 1.0) * (u - 2.0) / 6.0
  );
  return dot(w, k);
}

// Streamlines either side of the middle.
const float kLines = 7.0;

float hash(vec2 p) {
  p = mod(p, 64.0);
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float v = (p.y - uOutlet.y) / uOutlet.w;
  float vc = clamp(v, 0.0, 1.0);
  // Air leaves fast and slows as it spreads: the scrolling coordinate is
  // stretched near the louver. It is also how far along its trip the air is.
  float s = vc * (0.6 + 0.4 * vc);
  float spread = max(knots(uSpread, s), 0.0);
  float len = clamp(knots(uLength, s), 0.3, 1.0);

  // Straight down out of the louver, then flaring out (the painter's
  // AirStream.at is the same curve).
  float halfWidth = uOutlet.z * (1.0 + spread * 1.5 * vc * (0.4 + 0.6 * vc));
  float x = (p.x - uOutlet.x - uShape.x * vc * vc) / halfWidth;
  float t = uFlow;

  // The lines sway together, a slow wave travelling down them; warm air
  // wavers more.
  float sway = (noise(vec2(x * 1.2 + 4.0, s * 1.5 - t)) - 0.5) * 0.30
             + (noise(vec2(x * 2.4 + 9.0, s * 3.0 - t * 2.0)) - 0.5) * 0.08;
  if (uMode > 0.5 && uMode < 1.5) {
    sway += sin(vc * 18.0 - t * 6.2831853) * 0.035 * vc;
  }

  // Which streamline, and how far from its middle.
  float u = (x + sway) * kLines;
  float cell = floor(u + 0.5);
  float jitter = (hash(vec2(cell, 3.0)) - 0.5) * 0.3;
  float d = abs(u - cell - jitter);
  float width = mix(0.05, 0.13, vc); // nearer, wider and softer
  float core = 1.0 - smoothstep(0.0, width, d);
  float halo = 1.0 - smoothstep(0.0, width * 2.6, d);
  float weight = 0.45 + 0.55 * hash(vec2(cell, 11.0));

  // Rushes of brighter air running down each line.
  float rush = smoothstep(0.30, 0.85, noise(vec2(cell * 3.7, s * 2.5 - t * 3.0)));

  // The soft body round the lines.
  float mist = noise(vec2(x * 2.0 + sway * 2.0, vc * 2.0 - t)) * 0.6
             + noise(vec2(x * 4.0, vc * 4.0 - t * 2.0)) * 0.4;
  mist *= mist;

  float lines = (core * (0.22 + 0.78 * rush) + halo * rush * 0.30) * weight;
  float across = 1.0 - smoothstep(0.55, 1.0, abs(x));
  float along = smoothstep(0.0, 0.04, v)
              * (1.0 - smoothstep(0.35 * len, len, v));
  float front = 1.0 - smoothstep(uShape.z - 0.2, uShape.z, v);

  // A breath of cold (or warm) air right under the louver.
  float breath = exp(-max(v, 0.0) * 8.0)
               * (1.0 - smoothstep(0.7, 1.0, abs(x)))
               * step(0.0, v) * 0.35;

  float body = (lines * (1.0 - 0.35 * vc) + mist * 0.38 * (0.4 + 0.6 * vc))
             * across * along;
  float a = clamp((body + breath) * front * uShape.y, 0.0, 1.0);

  vec3 col = mix(uNear, uFar, smoothstep(0.0, 0.85, vc / len));
  if (uMode > 3.5) {
    float m = smoothstep(0.4, 0.6, noise(vec2(x * 1.3 + 7.0, s * 1.5 - t)));
    col = mix(col, uWarm, m);
  }
  fragColor = vec4(col * a, a);
}
