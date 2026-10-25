shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(0.12,0.18,0.13,1.0);
varying vec3 world_point;
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(world_point.x*0.7+world_point.z*0.4+TIME*1.1)*0.025*UV.x;
}
void fragment(){
 float x=UV.x;
 float y=abs(UV.y-0.5)*2.0;
 float envelope=pow(max(0.0,sin(x*3.14159)),0.65);
 float needles=abs(sin((x*19.0-y*2.8)*3.14159));
 float edge=envelope*(0.35+0.65*needles);
 if(y>edge || x<0.015 || x>0.985) discard;
 float stem=1.0-smoothstep(0.02,0.065,y);
 float mottling=0.75+0.25*sin(world_point.x*31.0+world_point.z*27.0);
 ALBEDO=mix(leaf_color.rgb*mottling,vec3(0.15,0.12,0.08),stem*0.55);
 ROUGHNESS=0.95;
}
