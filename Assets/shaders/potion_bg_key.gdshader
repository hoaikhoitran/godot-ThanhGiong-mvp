shader_type canvas_item;

uniform float sat_threshold : hint_range(0.0, 1.0) = 0.10;
uniform float bright_min : hint_range(0.0, 1.0) = 0.62;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float mx = max(max(c.r, c.g), c.b);
    float mn = min(min(c.r, c.g), c.b);
    float sat = mx - mn;

    // Remove mostly neutral bright checkerboard pixels while keeping potion colors.
    if (sat < sat_threshold && mx > bright_min) {
        c.a = 0.0;
    }

    COLOR = c;
}
