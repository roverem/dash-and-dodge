shader_type canvas_item;

// Hover state toggled by GDScript
uniform bool is_hovered = false;

// Outline customization properties
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Red
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    // Check the size of one pixel in UV space
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    vec4 current_color = texture(TEXTURE, UV);
    
    // Only calculate outlines if the node is hovered and the current pixel is transparent
    if (is_hovered && current_color.a == 0.0) {
        float alpha = 0.0;
        
        // Sample 4 surrounding pixels (Up, Down, Left, Right)
        alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
        alpha += texture(TEXTURE, UV - vec2(0.0, size.y)).a;
        alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
        alpha += texture(TEXTURE, UV - vec2(size.x, 0.0)).a;
        
        // If any neighbor pixel is solid, color this pixel as the outline
        if (alpha > 0.0) {
            COLOR = outline_color;
        } else {
            COLOR = current_color;
        }
    } else {
        // Keep the original sprite colors completely unchanged
        COLOR = current_color;
    }
}
