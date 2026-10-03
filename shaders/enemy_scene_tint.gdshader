shader_type canvas_item;

uniform float desaturation : hint_range(0.0, 1.0) = 0.9;
uniform vec3 overlay_color : source_color = vec3(0.18, 0.25, 0.42);
uniform float overlay_strength : hint_range(0.0, 1.0) = 0.6;
uniform float brightness : hint_range(0.1, 2.0) = 1.0;

void fragment() {
	vec4 source = COLOR;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(source.rgb, vec3(luminance), desaturation);
	vec3 scene_matched = mix(muted, overlay_color, overlay_strength);
	COLOR = vec4(clamp(scene_matched * brightness, vec3(0.0), vec3(1.0)), source.a);
}
