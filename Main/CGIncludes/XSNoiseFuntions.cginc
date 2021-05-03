//Simplex Noise
float3 random3(float3 c)
{
	float j = 4096.0 * sin(dot(c, float3(17.0, 59.4, 15.0)));
	float3 r;
	r.z = frac(512.0 * j);
	j *= .125;
	r.x = frac(512.0 * j);
	j *= .125;
	r.y = frac(512.0 * j);
	return r - 0.5;
}

//skew constants for 3d simplex functions
const float F3 = 0.3333333;
const float G3 = 0.1666667;

//3d simplex noise
float simplex3d(float3 p)
{

	//calculate s and x
	float3 s = floor(p + dot(p, float3(F3,F3,F3)));
	float3 x = p - s + dot(s, float3(G3,G3,G3));

	//calculate i1 and i2
	float3 e = step(float3(0.0,0.0,0.0), x - x.yzx);
	float3 i1 = e * (1.0 - e.zxy);
	float3 i2 = 1.0 - e.zxy * (1.0 - e);

	//x1, x2, x3
	float3 x1 = x - i1 + G3;
	float3 x2 = x - i2 + 2.0 * G3;
	float3 x3 = x - 1.0 + 3.0 * G3;

	//2. find four surflets and store them in d
	float4 w, d;

	//calculate surflet weights
	w.x = dot(x, x);
	w.y = dot(x1, x1);
	w.z = dot(x2, x2);
	w.w = dot(x3, x3);

	//w fades from 0.6 at the center of the surflet to 0.0 at the margin
	w = max(0.6 - w, 0.0);

	//calculate surflet components
	d.x = dot(random3(s), x);
	d.y = dot(random3(s + i1), x1);
	d.z = dot(random3(s + i2), x2);
	d.w = dot(random3(s + 1.0), x3);

	//multiply d by w^4
	w *= w;
	w *= w;
	d *= w;

	//3. return the sum of the four surflets
	return dot(d, float4(52.0, 52.0, 52.0, 52.0));
}

float3 hash(float3 x)
{
	x = float3(dot(x, float3(127.1, 311.7, 74.7)),
		dot(x, float3(269.5, 183.3, 246.1)),
		dot(x, float3(113.5, 271.9, 124.6)));

	return frac(sin(x) * 43758.5453123);
}

// returns closest, second closest, and cell id
float3 voronoi(in float3 x)
{
	float3 p = floor(x);
	float3 f = frac(x);

	float id = 0.0;
	float2 res = float2(100.0,100.0);
	for (int k = -1; k <= 1; k++)
	{
		for (int j = -1; j <= 1; j++)
		{
			for (int i = -1; i <= 1; i++)
			{
				float3 b = float3(float(i), float(j), float(k));
				float3 r = float3(b) - f + hash(p + b);
				float d = dot(r, r);

				if (d < res.x)
				{
					id = dot(p + b, float3(1.0, 57.0, 113.0));
					res = float2(d, res.x);
				}
				else if (d < res.y)
				{
					res.y = d;
				}
			}
		}
	}
	return float3(sqrt(res), abs(id));
}
