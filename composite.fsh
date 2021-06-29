#version 400 compatibility


/*






!! DO NOT REMOVE !! !! DO NOT REMOVE !!

This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !! !! DO NOT REMOVE !!


Sharing and modification rules

Sharing a modified version of my shaders:
-You are not allowed to claim any of the code included in "Chocapic13' shaders" as your own
-You can share a modified version of my shaders if you respect the following title scheme : " -Name of the shaderpack- (Chocapic13' Shaders edit) "
-You cannot use any monetizing links
-The rules of modification and sharing have to be same as the one here (copy paste all these rules in your post), you cannot make your own rules
-I have to be clearly credited
-You cannot use any version older than "Chocapic13' Shaders V4" as a base, however you can modify older versions for personal use
-Common sense : if you want a feature from another shaderpack or want to use a piece of code found on the web, make sure the code is open source. In doubt ask the creator.
-Common sense #2 : share your modification only if you think it adds something really useful to the shaderpack(not only 2-3 constants changed)


Special level of permission; with written permission from Chocapic13, if you think your shaderpack is an huge modification from the original (code wise, the look/performance is not taken in account):
-Allows to use monetizing links
-Allows to create your own sharing rules
-Shaderpack name can be chosen
-Listed on Chocapic13' shaders official thread
-Chocapic13 still have to be clearly credited


Using this shaderpack in a video or a picture:
-You are allowed to use this shaderpack for screenshots and videos if you give the shaderpack name in the description/message
-You are allowed to use this shaderpack in monetized videos if you respect the rule above.


Minecraft website:
-The download link must redirect to the link given in the shaderpack's official thread
-You are not allowed to add any monetizing link to the shaderpack download

If you are not sure about what you are allowed to do or not, PM Chocapic13 on http://www.minecraftforum.net/
Not respecting these rules can and will result in a request of thread/download shutdown to the host/administrator, with or without warning. Intellectual property stealing is punished by law.











*/
#define UNDERWATERFIX //fixes shadows and other stuff underwater
/*--------------------------------*/
in vec2 texcoord;
in vec3 lightColor;
in vec3 avgAmbient;
in vec3 lightVector;
in vec3 sunVec;
in vec3 moonVec;
in vec3 upVec;
in vec3 avgAmbient2;
in vec3 sky1;
in vec3 sky2;
in vec3 cloudColor;
in vec3 cloudColor2;
in float tr;

in vec4 lightS;
in vec2 lightPos;

in vec3 sunlight;
in vec3 ambient_color;
in vec3 nsunlight;

in float handItemLight;
in float eyeAdapt;
in vec3 rawAvg;

in float SdotU;
in float MdotU;
in float sunVisibility;
in float moonVisibility;

uniform sampler2D gaux1;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D gdepthtex;
uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2DShadow shadow;


const int 		noiseTextureResolution  = 1024;
uniform vec3 cameraPosition;
uniform float potato;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferPreviousModelView;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform int isEyeInWater;
uniform int worldTime;
uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
uniform int fogMode;
uniform int heldBlockLightValue;
const vec3 moonlight = vec3(0.5, 0.9, 1.4) * 0.016;
const vec3 moonlightS = vec3(0.5, 0.9, 1.4) * 0.001;
float comp = 1.0-near/far/far;			//distance above that are considered as sky
float invRain06 = 1.0-rainStrength*0.6;



vec3 decode (vec2 enc)
{
    vec2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = sqrt(1-f/4.0);
    vec3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}

float ditherTable4x4 (vec2 tc){
	const mat4 dither = mat4(0.0/16. , 8.0/16. , 2.0/16. , 10.0/16.,
							 12.0/16., 4.0/16. , 14.0/16., 6.0/16. ,
							 3.0/16. , 11.0/16., 1.0/16.,  9.0/16. ,
							 15.0/16., 7.0/16. , 13.0/16., 5.0/16. );
	return dither[int(tc.x)][int(tc.y)];
}
void ssao(inout float occlusion,  vec2 tex,vec3 fragpos,float mulfov)
{
	const float tan70 = tan(70.*3.14/180.);
	float mulfov2 = gbufferProjection[1][1]/tan70; 

	const int ndirs = 3;
	const int num_samples = 4;
	const float PI = 3.14159265;
	vec3 center_pos  = fragpos.rgb;
	const float samplingRadius = 3.5;
	float radius = 0.5/ (-center_pos.z);
	float angle_thresh = 0.05;

	
	//setup 4x4 noise pattern on two direction per pixel
	vec2 nTC = mod(floor(gl_FragCoord.xy),4.0);
	float noise = ditherTable4x4(nTC)*6.28;
	mat2 noiseM = mat2( cos( noise ), -sin( noise ),
                           sin( noise ), cos( noise )
                            );


	vec3 normal = normalize(decode(texture2DLod(gdepth,tex,0).xy));
	vec2 rd = vec2(radius,radius*aspectRatio)/num_samples*mulfov2;
	//pre-rotate direction
	float n =0.;

		
	for (int i = 0; i < ndirs; i++){
		vec2 dir = noiseM*(vec2(cos(PI*2.0/ndirs*i),sin(PI*2.0/ndirs*i))*rd);	//jitter the directions
		for(int j = 0; j < num_samples; j++) {
			//Marching Time
			vec2 sampleOffset = float(j + noise/6.28) * dir*vec2(1.0,aspectRatio);	//jitter start position to get better space coverage
		vec2 offset = floor((tex + sampleOffset)*vec2(viewWidth,viewHeight))/vec2(viewWidth,viewHeight)+0.5/vec2(viewWidth,viewHeight);  //perspective-correct coordinates
		if (abs(offset.x-0.5)<0.5 && abs(offset.y-0.5)<0.5 && (abs(offset.x-texcoord.x) > 0.999999/viewWidth || abs(offset.y-texcoord.y) > 0.999999/viewHeight)){		//discard if sampling original texel or out of screen
		vec4 t0 = gbufferProjectionInverse*vec4(vec3(offset,texture2D(depthtex1,offset).x)*2.0-1.0,1.0);
		t0 /= t0.w;
		t0.xy *= mulfov;
			vec3 vec = t0.xyz - fragpos.xyz;
			float NdotV = dot(normalize(vec), normal);
			float l2 = dot(vec,vec);
			occlusion += clamp(NdotV - angle_thresh,0.0,1.0) * clamp(1.0-l2/samplingRadius,0.0,1.0)/(1.0-angle_thresh);
			n+=1.0;
		}
		}
	}

		occlusion = 1.0-pow(occlusion/max(n,1.),1./2.0);

}
float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}

vec3 drawSun(vec3 fposition,vec3 color) {
vec3 sVector = normalize(fposition);

float angle = (1.0-max(dot(sVector,sunVec),0.0))*650;
float sun = exp(-angle*angle*angle);
sun *= (1.0-rainStrength*0.9925)*sunVisibility;
vec3 sunlightB = mix(pow(sunlight,vec3(1.0))*2.2*20.,vec3(0.25,0.3,0.4),rainStrength*0.8);

return mix(color,sunlightB,sun);

}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
void main() {
//sample half-resolution buffer with correct texture coordinates
//vec4 hr = pow(texture2D(composite,(floor(gl_FragCoord.xy/2.)*2+1.0)/vec2(viewWidth,viewHeight)/2.0),vec4(2.2,2.2,2.2,1.0))*vec4(257.,257,257,1.0);

float occlusion = 0.;

vec2 ntc = texcoord;

float Depth = texture2D(depthtex1, ntc).x;
vec4 albedo = texture2D(gcolor,ntc);
bool land = !(dot(albedo.rgb,vec3(1.0))<0.00000000001 || (Depth > comp));


if (land){
#ifdef UNDERWATERFIX
float mulfov = 1.0;
if (isEyeInWater>0.1){
float fov = atan(1./gbufferProjection[1][1]);
float fovUnderWater = fov*0.85;
mulfov = gbufferProjection[1][1]*tan(fovUnderWater); 
}
#endif
#ifndef UNDERWATERFIX
const float mulfov = 1.0;
#endif
vec4 fragpos = gbufferProjectionInverse * (vec4(ntc,Depth,1.0) * 2.0 - 1.0);
fragpos /= fragpos.w;
fragpos.xy *= mulfov;

vec3 normalT = decode(texture2D(gdepth,ntc).xy);
ssao(occlusion,ntc,fragpos.xyz,mulfov);
}


/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(vec3(occlusion),1.0);
}
