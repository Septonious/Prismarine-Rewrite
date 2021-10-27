float gray = 0.15;
if(abs(vTexCoord.y - 0.5) * 2.0 > 7.0/8.0) gray = 0.2;
if(abs(vTexCoord.y - 0.5) * 2.0 < 1.0/8.0) gray = 0.2;
if(abs(vTexCoord.x - 0.5) * 2.0 > 7.0/8.0) gray = 0.5;
albedo.rgb = vec3(gray);
float glowb = 0.0;
glowb = float(vTexCoord.y > 2.0/16.0 && vTexCoord.y < 3.0/16.0);
glowb+= float(vTexCoord.y > 5.0/16.0 && vTexCoord.y < 6.0/16.0);
glowb+= float(vTexCoord.y > 10.0/16.0 && vTexCoord.y < 11.0/16.0);
glowb+= float(vTexCoord.y > 13.0/16.0 && vTexCoord.y < 14.0/16.0);
glowb *= float(vTexCoord.x > 2.0/16.0 && vTexCoord.x < 14.0/16.0);

vec3 wpos = floor((worldPos + cameraPosition) + 0.5);
vec2 vtex = floor(vTexCoord.xy * 16.0) + 1;
float noise = fract(vtex.x * 0.7123123 + vtex.y * 0.412414 + wpos.x * 0.21231 + wpos.y * 0.423123 + wpos.z * 0.71341);

float glowg = 0.0;
glowg = float(vTexCoord.x > 13.0/16.0 && vTexCoord.x < 14.0/16.0);
glowg += float(vTexCoord.x > 11.0/16.0 && vTexCoord.x < 12.0/16.0);
glowg *= float(vTexCoord.y > 15.0/16.0 && vTexCoord.y < 16.0/16.0);
glowg *= float(noise > 0.25);

if(glowb > 0.5){
	albedo.rgb = vec3(0.35,0.7,1.0);
	emission = 1.0;
}
if(glowg > 0.5){
	albedo.rgb = vec3(0.4,1.0,0.4);
	emission = 1.0;
}