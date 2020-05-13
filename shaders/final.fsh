#version 330 compatibility

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;

uniform sampler2D noisetex;
const int noiseTextureResolution = 256;

uniform int frameCounter;

uniform int worldTime;
uniform int worldDay;

uniform float near;
uniform float far;

uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;

in vec2 texUV;

out vec4 frag;

float linearizeDepth(float depth)
{
    return (2.0 * near) / (far + near - depth * (far - near));
}

float logarithmDepth(float depth)
{
    return (far + near - 2 * near / depth) / (far - near);
}

#define CLOUD_HEIGHT 300 // [300 500 1000 3000]
#define CLOUD_SIZE_DIV 3 // [1 2 3 4 5]
#define CLOUD_SIZE (CLOUD_HEIGHT / CLOUD_SIZE_DIV)
#define CLOUD_THINKNESS_DIV 8 // [0 2 4 8 16]
#define CLOUD_THINKNESS (CLOUD_SIZE / CLOUD_THINKNESS_DIV)
#define CLOUD_SPEED 2 // [0 2 6 10 20]
#define CLOUD_STEP 16 // [16 32 64 128 256]
#define CLOUD_DESITY 25 // [10 25 50 100 300]

vec2 pixelCenter(vec2 uv, float texSize)
{
    float size = 1.0 / texSize;
    vec2 p = uv;
    p /= size;
    p = floor(p);
    p *= size;
    p += size * 0.5;
    return p;
}

float cloudTest(vec3 pos)
{
    vec2 cloudUV = pos.xz;
    cloudUV /= noiseTextureResolution * CLOUD_SIZE;
    cloudUV = fract(cloudUV);
    float noise = texture(noisetex, pixelCenter(cloudUV, noiseTextureResolution)).x;
    if (noise > 100.0 / (100 + CLOUD_DESITY))
        return 1.0;
    return 0.0;
}

float cloudRayMarching(vec3 pos, vec3 dir)
{
    float add = frameCounter / 720719.0 * noiseTextureResolution * CLOUD_SIZE * CLOUD_SPEED;
    pos.x += add;

#if CLOUD_THINKNESS_DIV > 0
    dir /= dir.y * CLOUD_STEP / CLOUD_THINKNESS;
    for (; pos.y < CLOUD_HEIGHT + CLOUD_THINKNESS + 0.01; pos += dir)
#endif
        if (cloudTest(pos) > 0.5)
            return 1.0;
    return 0.0;
}

#define CLOUD_SHADOW_BLUR 0 // [0 1 2 4]

float cloudMulCalc(float pos1, float pos2)
{
    return smoothstep(0, 1, max(pos1 - pos2 - (0.5 - 0.5 / CLOUD_SHADOW_BLUR) * CLOUD_SIZE, 0) / CLOUD_SIZE * 2.0 * CLOUD_SHADOW_BLUR);
}

float cloudMulCalcCircle(float pos1, float pos2, float pos3, float pos4)
{
    return max(1 - length(vec2(1 - cloudMulCalc(pos1, pos2), 1 - cloudMulCalc(pos3, pos4))), 0);
}

float cloudShadow(vec4 camPos)
{
    vec3 rayDir = normalize(shadowModelViewInverse[3].xyz); // shadowModelViewInverse[3].xyz = gbufferModelInverse * shadowLightPosition


    if (rayDir.y > 0.1)
    {
        vec3 cloud = camPos.xyz + cameraPosition;
        cloud += rayDir * (CLOUD_HEIGHT - camPos.y - cameraPosition.y) / rayDir.y;
#if CLOUD_SHADOW_BLUR > 0
        float add = frameCounter / 720719.0 * noiseTextureResolution * CLOUD_SIZE * CLOUD_SPEED;
        cloud.x += add;
        float shadow = cloudTest(cloud);
#else
        float shadow = cloudRayMarching(cloud, rayDir);
#endif
        if (shadow > 0.5)
            return 1.0;
        
        vec2 cloudCenter = pixelCenter(cloud.xz, 1.0 / CLOUD_SIZE);

#if CLOUD_SHADOW_BLUR > 0
        vec3 pos = vec3(0);
        float offset = CLOUD_SIZE * 0.5 / CLOUD_SHADOW_BLUR;

        pos = cloud;
        pos.x -= offset;
        float shadowL = cloudMulCalc(cloudCenter.x, cloud.x) * cloudTest(pos);
        shadow = mix(shadow, 1.0, shadowL);

        pos = cloud;
        pos.z -= offset;
        float shadowU = cloudMulCalc(cloudCenter.y, cloud.z) * cloudTest(pos);
        shadow = mix(shadow, 1.0, shadowU);

        pos = cloud;
        pos.x += offset;
        float shadowR = cloudMulCalc(cloud.x, cloudCenter.x) * cloudTest(pos);
        shadow = mix(shadow, 1.0, shadowR);

        pos = cloud;
        pos.z += offset;
        float shadowD = cloudMulCalc(cloud.z, cloudCenter.y) * cloudTest(pos);
        shadow = mix(shadow, 1.0, shadowD);

        float tmpShadow = 0.0;

        pos = cloud;
        pos.x -= offset;
        pos.z -= offset;
        tmpShadow = cloudMulCalcCircle(cloudCenter.x, cloud.x, cloudCenter.y, cloud.z) * cloudTest(pos);
        shadow = mix(mix(shadow, 1.0, tmpShadow), shadow, step(0.00001, shadowL + shadowU)); // if (shadowL < 0.00001 && shadowU < 0.00001) shadow = mix(shadow, 1.0, tmpShadow);

        pos = cloud;
        pos.x -= offset;
        pos.z += offset;
        tmpShadow = cloudMulCalcCircle(cloudCenter.x, cloud.x, cloud.z, cloudCenter.y) * cloudTest(pos);
        shadow = mix(mix(shadow, 1.0, tmpShadow), shadow, step(0.00001, shadowL + shadowD));

        pos = cloud;
        pos.x += offset;
        pos.z -= offset;
        tmpShadow = cloudMulCalcCircle(cloud.x, cloudCenter.x, cloudCenter.y, cloud.z) * cloudTest(pos);
        shadow = mix(mix(shadow, 1.0, tmpShadow), shadow, step(0.00001, shadowR + shadowU));

        pos = cloud;
        pos.x += offset;
        pos.z += offset;
        tmpShadow = cloudMulCalcCircle(cloud.x, cloudCenter.x, cloud.z, cloudCenter.y) * cloudTest(pos);
        shadow = mix(mix(shadow, 1.0, tmpShadow), shadow, step(0.00001, shadowR + shadowD));
#endif

        return clamp(shadow, 0.0, 1.0);
    }
    else
        return 0.0;
}

#define SHADOW_MAP_BIAS 0.9

float sunlight(vec4 camPos)
{
    vec4 shadowPosition = shadowProjection * shadowModelView * camPos;
    vec4 shadowBIASPos = shadowPosition;
    float dist = length(shadowPosition.xy);
    float distortFactor = mix(1.0, dist, SHADOW_MAP_BIAS);
    shadowBIASPos.xy /= distortFactor;
    shadowBIASPos /= shadowBIASPos.w;
    shadowBIASPos = shadowBIASPos * 0.5 + 0.5;
    float shadowDepth = texture2D(shadowtex0, shadowBIASPos.xy).z;
    if (shadowDepth >= shadowBIASPos.z - 0.0001)
        return 1.0 - cloudShadow(camPos) * 0.5;
    else
        return 0.5;
}

void main()
{
    // “体积”云
    float depth = texture(depthtex0, texUV).z;

    vec4 viewPos = gbufferProjectionInverse * vec4(texUV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    viewPos /= viewPos.w;
    vec4 camPos = gbufferModelViewInverse * viewPos;

    vec4 color = texture(colortex0, texUV);

    vec3 rayDir = normalize(camPos.xyz);
    float dist = linearizeDepth(depth);
    if (rayDir.y > 0.1)
    {
        vec3 cloud = cameraPosition;
        cloud += rayDir * (CLOUD_HEIGHT - cameraPosition.y) / rayDir.y;

        if(dist > 0.9999 || camPos.y + cameraPosition.y >= CLOUD_HEIGHT)
        {
            if (cloudRayMarching(cloud, rayDir) > 0.5)
                color.rgb = vec3(1);
        }
    }
    // 没写从高往低看的判断

    // 阴影
    if (dist < 0.9999)
    {
        color.rgb *= sunlight(camPos);
    }

    frag = color;
}