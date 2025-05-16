shader_type spatial;

uniform sampler2D albedo_texture : filter_linear_mipmap, repeat_enable;
uniform float speed = 1.0;
uniform vec2 flow_direction = vec2(1.0, 0.0);

void fragment() {
    vec2 uv_offset = flow_direction * TIME * speed;
    vec4 tex_color = texture(albedo_texture, UV + uv_offset);
    
    // Если текстура имеет прозрачность, учитываем её
    ALBEDO = tex_color.rgb;
    ALPHA = tex_color.a;  // Используем альфа-канал текстуры для прозрачности
}

void vertex() {
    // Дополнительные преобразования для вершин (если нужно)
}
