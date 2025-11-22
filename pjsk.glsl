// Project Sekai-like shader
// The effect is mediocre; only looks somewhat similar to PJSK

const int MAX_ITER = 32;
const float MAX_DIST = 24.0;
const float EPSILON = 0.005;

const float speed = 0.2;
const float shard_brightness = 1.2; 
const float shard_rotation_speed = 1.2;
const float camera_rotation_speed = 0.05;

vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return fract((p3.xxy + p3.yxx)*p3.zyx);
}

mat3 rotationMatrix(vec3 m, float a) {
    m = normalize(m);
    float c = cos(a), s = sin(a);
    return mat3(c+(1.-c)*m.x*m.x,
        (1.-c)*m.x*m.y-s*m.z,
        (1.-c)*m.x*m.z+s*m.y,
        (1.-c)*m.x*m.y+s*m.z,
        c+(1.-c)*m.y*m.y,
        (1.-c)*m.y*m.z-s*m.x,
        (1.-c)*m.x*m.z-s*m.y,
        (1.-c)*m.y*m.z+s*m.x,
        c+(1.-c)*m.z*m.z);
}

float sdEquilateralTriangle( in vec2 p, in float r )
{
    const float k = 1.73205; // sqrt(3.0)
    p.x = abs(p.x) - r;
    p.y = p.y + r/k;
    if( p.x+k*p.y > 0.0 ) p = vec2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0*r, 0.0 );
    return -length(p)*sign(p.y);
}

float paperShard(vec3 pos, float size, vec3 rnd)
{
    float t = iTime;
    
    vec3 rotAxis = normalize(vec3(sin(rnd.x*6.28), cos(rnd.y*6.28), rnd.z*0.5));
    float wobble = sin(t * 0.5 + rnd.y * 10.0) * 0.2;
    
    pos = pos * rotationMatrix(rotAxis, t * speed * shard_rotation_speed * (0.8 + rnd.z) + rnd.x * 10.0 + wobble);
    
    vec2 triPos = pos.xy;

    triPos.x *= 1.0 + rnd.x * 0.5;
    triPos.y *= 1.0 + rnd.z * 0.5;

    float dTri = sdEquilateralTriangle(triPos, size);
    float dThickness = abs(pos.z) - 0.002;
    
    return max(dTri, dThickness);
}

float distfunc(vec3 pos)
{
    float t = iTime;
    float gridSize = 5.5; 
    
    vec3 id = floor(pos / gridSize);
    vec3 rnd = hash33(id);
    
    vec3 q = mod(pos, gridSize) - gridSize * 0.5;
    vec3 offset = (rnd - 0.5) * 3.5;
   
    q -= offset;

    float size = 0.3 + 0.3 * rnd.x; 
    float pulse = 0.9 + 0.1 * sin(t * speed + rnd.y * 6.28);
   
    size *= pulse;

    return paperShard(q, size, rnd);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float t = iTime;
    vec2 screenPos = -1.0 + 2.0 * fragCoord.xy / iResolution.xy;
   
    screenPos.x *= iResolution.x / iResolution.y;
    
    vec3 cameraOrigin = vec3(t*0.8*speed, 0.0, 0.0);
    vec3 cameraTarget = vec3(t*100., 0.0, 0.0);
    
    cameraTarget = vec3(t*20.0,0.0,0.0) * rotationMatrix(vec3(0.0,0.0,1.0), t*speed*camera_rotation_speed);
    
    vec3 upDirection = vec3(0.0, 1.0, 0.0);
    vec3 cameraDir = normalize(cameraTarget - cameraOrigin);
    vec3 cameraRight = normalize(cross(upDirection, cameraOrigin));
    vec3 cameraUp = cross(cameraDir, cameraRight);
    vec3 rayDir = normalize(cameraRight * screenPos.x + cameraUp * screenPos.y + cameraDir);
    float totalDist = 0.0;
    vec3 pos = cameraOrigin;
    float dist = EPSILON;
    
    for (int i = 0; i < MAX_ITER; i++)
    {
        if (dist < EPSILON || totalDist > MAX_DIST) break;
        dist = distfunc(pos);
        totalDist += dist;
        pos += dist*rayDir;
    }

    vec4 finalColor;

    if (dist < EPSILON)
    {
        vec2 eps = vec2(0.0, EPSILON);
        vec3 normal = normalize(vec3(
            distfunc(pos + eps.yxx) - distfunc(pos - eps.yxx),
            distfunc(pos + eps.xyx) - distfunc(pos - eps.xyx),
            distfunc(pos + eps.xxy) - distfunc(pos - eps.xxy)));
        
        float diffuse = max(0.2, abs(dot(-rayDir, normal))); 
        float specular = pow(max(0., dot(reflect(rayDir, normal), -rayDir)), 16.0) * 0.5;
        vec3 baseColor = 0.5 + 0.5*cos(pos.z*0.2 + vec3(0.0, 2.0, 4.0)); 
       
        baseColor = mix(vec3(0.1, 0.1, 0.15), baseColor, 0.5);

        vec3 color = baseColor * diffuse + vec3(specular);
        float fog = 1.0 - (totalDist / MAX_DIST);

        fog = pow(fog, 1.5);
        finalColor = vec4(color * fog * shard_brightness, 1.0);
    } 
    else {
        finalColor = vec4(0.0);
    }
    vec2 uv = fragCoord/iResolution.xy;
    vec4 terminalColor = texture(iChannel0, uv);
    vec3 blendedColor = terminalColor.rgb + finalColor.rgb * 0.6;
    fragColor = vec4(blendedColor, terminalColor.a);
}
