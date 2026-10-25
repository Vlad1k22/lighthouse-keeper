shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.3, 0.3, 0.25, 1.0);
// 0 rock, 1 wood, 2 plaster, 3 fabric, 4 soil, 5 gravel, 6 metal.
uniform int surface_kind = 0;
varying vec3 world_point;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment() {
 vec3 p=world_point;
 float broad=noise3(p*1.6), fine=noise3(p*22.0), grit=noise3(p*55.0);
 float damp=noise3(p*0.53+vec3(4,0,8));
 vec3 tint=base_color.rgb;
 tint=mix(vec3(dot(tint,vec3(0.3,0.59,0.11))),tint,0.68);
 vec3 col=tint*(0.64+broad*0.48+fine*0.22);
 float rough=0.88;
 if(surface_kind==1){
  float grain=noise3(p*vec3(40,0.65,40));
  float splits=smoothstep(0.76,0.92,noise3(p*vec3(95,1.8,95)));
  col=tint*(0.52+grain*0.48+broad*0.30)*(1.0-splits*0.46);
  col=mix(col,vec3(0.12,0.14,0.115),smoothstep(0.55,0.8,damp)*0.32);
 }else if(surface_kind==2){
  float streak=noise3(p*vec3(14,0.24,14));
  float chips=smoothstep(0.58,0.72,noise3(p*8.0))*smoothstep(0.38,0.63,broad);
  col=mix(tint*(0.72+streak*0.32),vec3(0.15,0.16,0.15),chips*0.5);
  col*=0.88+fine*0.20;
 }else if(surface_kind==3){
  float weave=sin(p.y*260.0)*sin((p.x+p.z)*260.0);
  col=tint*(0.70+broad*0.30+weave*0.045);
 }else if(surface_kind==4){
  float patch=noise3(p*0.42)+noise3(p*2.8)*0.28;
  col=mix(vec3(0.12,0.115,0.085),vec3(0.23,0.26,0.17),smoothstep(0.32,0.8,patch));
  col*=0.80+fine*0.25+grit*0.08;
  rough=mix(0.62,0.97,damp);
 }else if(surface_kind==5){
  col=mix(vec3(0.19,0.18,0.15),vec3(0.32,0.31,0.26),broad)*(0.66+fine*0.48);
  float pebbles=smoothstep(0.70,0.80,grit);
  col+=pebbles*0.075;
 }else if(surface_kind==6){
  float rust=smoothstep(0.44,0.65,noise3(p*9.0));
  col=mix(tint,vec3(0.23,0.12,0.065),rust*0.7)*(0.7+fine*0.35);
  rough=0.72;
 }else{
  float fissure=1.0-smoothstep(0.01,0.065,abs(noise3(p*5.0)-0.5));
  col*=1.0-fissure*0.3;
  col=mix(col,vec3(0.10,0.13,0.10),smoothstep(0.58,0.82,damp)*0.32);
  rough=0.8;
 }
 ALBEDO=max(col,vec3(0.01));
 ROUGHNESS=rough;
 SPECULAR=0.10;
 // Fine surface relief, independent of imported texture UVs.
 NORMAL_MAP=normalize(vec3((fine-0.5)*0.28,(grit-0.5)*0.20,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=0.15;
}
