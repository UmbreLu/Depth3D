 ////---------------//
 ///**Smart Sharp**///
 //---------------////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Depth Based Unsharp Mask Bilateral Contrast Adaptive Sharpening                                     																										
// For Reshade 3.0+																																					
// --------------------------																																			
// Have fun,																																								
// Jose Negrete AKA BlueSkyDefender																																		
// 																																											
// https://github.com/BlueSkyDefender/Depth3D																	
//  ---------------------------------																																	                                                                                                        																	
// 								Bilateral Filter Made by mrharicot ported over to Reshade by BSD													
//								 GitHub Link for sorce info github.com/SableRaf/Filters4Processin																
// 								Shadertoy Link https://www.shadertoy.com/view/4dfGDH  Thank You.
//                                                       
// LICENSE
// =======
// Copyright (c) 2017-2019 Advanced Micro Devices, Inc. All rights reserved.
// -------
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// -------
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
// -------
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// This is the practical limit for the algorithm's scaling ability. Example resolutions,
//  1280x720  -> 1080p = 2.25x area
//  1536x864  -> 1080p = 1.56x area
//  1792x1008 -> 1440p = 2.04x area
//  1920x1080 -> 1440p = 1.78x area
//  1920x1080 ->    4K =  4.0x area
//  2048x1152 -> 1440p = 1.56x area
//  2560x1440 ->    4K = 2.25x area
//  3072x1728 ->    4K = 1.56x area

// Determines the power of the Bilateral Filter and sharpening quality. Lower the setting the more performance you would get along with lower quality.
// 0 = Off
// 1 = Low
// 2 = Default 
// 3 = Medium
// 4 = High 
// Default is off.
#define M_Quality 0 //ManualQuality Shader Defaults to 2

// It is best to run Smart Sharp after tonemapping.

#if !defined(__RESHADE__) || __RESHADE__ < 40000
	#define Compatibility 1
#else
	#define Compatibility 0
#endif

uniform int Depth_Map <
	ui_type = "combo";
	ui_items = "Normal\0Reverse\0";
	ui_label = "Custom Depth Map";
	ui_tooltip = "Pick your Depth Map.";
	ui_category = "Depth Buffer";
> = 0;

uniform float Depth_Map_Adjust <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 1.0; ui_max = 1000.0; ui_step = 0.125;
	ui_label = "Depth Map Adjustment";
	ui_tooltip = "Adjust the depth map and sharpness distance.";
	ui_category = "Depth Buffer";
> = 250.0;

uniform bool Depth_Map_Flip <
	ui_label = "Depth Map Flip";
	ui_tooltip = "Flip the depth map if it is upside down.";
	ui_category = "Depth Buffer";
> = false;

uniform bool No_Depth_Map <
	ui_label = "No Depth Map";
	ui_tooltip = "If you have No Depth Buffer turn this On.";
	ui_category = "Depth Buffer";
> = false;

uniform float Sharpness <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
    ui_label = "Sharpening Strength";
    ui_min = 0.0; ui_max = 1.0;
    ui_tooltip = "Scaled by the sharpness knob while being transformed to a negative lobe (values at -1/5 * adjust).\n"
				 "Zero = no sharpening, to One = full sharpening, Past One = Extra Crispy.\n"
				 "Number 0.625 is default.";
	ui_category = "Bilateral CAS";
> = 0.625;

uniform bool CAS_BETTER_DIAGONALS <
	ui_label = "CAS Better Diagonals";
	ui_tooltip = "Instead of using the 3x3 'box' with the 5-tap 'circle' this uses just the 'circle'.";
	ui_category = "Bilateral CAS";
> = false;

uniform bool CAS_Mask_Boost <
	ui_label = "CAS Boost";
	ui_tooltip = "This boosts the power of Contrast Adaptive Masking part of the shader.";
	ui_category = "Bilateral CAS";
> = false;

uniform int Debug_View <
	ui_type = "combo";
	ui_items = "Normal View\0Sharp Debug\0Z-Buffer Debug\0";
	ui_label = "View Mode";
	ui_tooltip = "This is used to select the normal view output or debug view.\n"
				 "Used to see what the shaderis changing in the image.\n"
				 "Normal gives you the normal out put of this shader.\n"
				 "Sharp is the full Debug for Smart sharp.\n"
				 "Depth Cues is the Shaded output.\n"
				 "Z-Buffer id Depth Buffer only.\n"
				 "Default is Normal View.";
	ui_category = "Debug";
> = 0;

#define Quality 2

#if M_Quality > 0
	#undef Quality
    #define Quality M_Quality
#endif
/////////////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)

#define SIGMA 10
#define BSIGMA 0.25

#if Quality == 1
	#define MSIZE 3
#endif
#if Quality == 2
	#define MSIZE 5
#endif
#if Quality == 3
	#define MSIZE 7
#endif
#if Quality == 4
	#define MSIZE 9
#endif

texture DepthBufferTex : DEPTH;

sampler DepthBuffer 
	{ 	
		Texture = DepthBufferTex; 
	};
	
texture BackBufferTex : COLOR;	

sampler BackBuffer 
	{ 
		Texture = BackBufferTex;
	};
				
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float Depth(in float2 texcoord : TEXCOORD0)
{
	if (Depth_Map_Flip)
		texcoord.y =  1 - texcoord.y;
		
	float zBuffer = tex2D(DepthBuffer, texcoord).x; //Depth Buffer
	
	//Conversions to linear space.....
	//Near & Far Adjustment
	float Far = 1.0, Near = 0.125/Depth_Map_Adjust; //Division Depth Map Adjust - Near
	
	float2 Z = float2( zBuffer, 1-zBuffer );
	
	if (Depth_Map == 0)//DM0. Normal
		zBuffer = Far * Near / (Far + Z.x * (Near - Far));		
	else if (Depth_Map == 1)//DM1. Reverse
		zBuffer = Far * Near / (Far + Z.y * (Near - Far));	
		 
	return saturate(zBuffer);	
}	

float3 Min3(float3 x, float3 y, float3 z)
{
    return min(x, min(y, z));
}

float3 Max3(float3 x, float3 y, float3 z)
{
    return max(x, max(y, z));
}

float normpdf(in float x, in float sigma)
{
	return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
}

float normpdf3(in float3 v, in float sigma)
{
	return 0.39894*exp(-0.5*dot(v,v)/(sigma*sigma))/sigma;
}

float3 BB(in float2 texcoord, float2 AD)
{
	return tex2Dlod(BackBuffer, float4(texcoord + AD,0,0)).rgb;
}

float4 CAS(float2 texcoord)
{
	// fetch a 3x3 neighborhood around the pixel 'e',
	//  a b c
	//  d(e)f
	//  g h i
	float3 A = tex2Doffset(BackBuffer, texcoord, int2(-1,-1)).rgb;
    float3 B = tex2Doffset(BackBuffer, texcoord, int2( 0,-1)).rgb;
    float3 C = tex2Doffset(BackBuffer, texcoord, int2( 1,-1)).rgb;
    float3 D = tex2Doffset(BackBuffer, texcoord, int2(-1, 0)).rgb;
    float3 E = tex2Doffset(BackBuffer, texcoord, int2( 0, 0)).rgb;
    float3 F = tex2Doffset(BackBuffer, texcoord, int2( 1, 0)).rgb;
    float3 G = tex2Doffset(BackBuffer, texcoord, int2(-1, 1)).rgb;
    float3 H = tex2Doffset(BackBuffer, texcoord, int2( 0, 1)).rgb;
    float3 I = tex2Doffset(BackBuffer, texcoord, int2( 1, 1)).rgb;
	// Soft min and max.
	//  a b c             b
	//  d e f * 0.5  +  d e f * 0.5
	//  g h i             h
    // These are 2.0x bigger (factored out the extra multiply).
    float3 mnRGB2, mnRGB = Min3( Min3(D, E, F), B, H);
	
	if( CAS_BETTER_DIAGONALS)
    {
		mnRGB2 = Min3( Min3(mnRGB, A, C), G, I);
		mnRGB += mnRGB2;
	}
    
    float3 mxRGB2, mxRGB = Max3( Max3(D, E, F), B, H);
    
    if( CAS_BETTER_DIAGONALS )
    {
		mxRGB2 = Max3( Max3(mxRGB, A, C), G, I);  
		mxRGB += mxRGB2;
    }
    
    // Smooth minimum distance to signal limit divided by smooth max.
    float3 ampRGB, rcpMRGB = rcp(mxRGB);

	if( CAS_BETTER_DIAGONALS)
		ampRGB = saturate(min(mnRGB, 2.0 - mxRGB) * rcpMRGB);
	else
		ampRGB = saturate(min(mnRGB, 1.0 - mxRGB) * rcpMRGB);
    
    // Shaping amount of sharpening.
    ampRGB = sqrt(ampRGB);
      
	//Bilateral Filter//                                                                                                                                                                   
	float3 c = BB(texcoord.xy,0);
	const int kSize = MSIZE * 0.5;	
//													1			2			3			4				5			6			7			8				7			6			5				4			3			2			1
//Full Kernal Size would be 15 as shown here (0.031225216, 0.03332227	1, 0.035206333, 0.036826804, 0.038138565, 0.039104044, 0.039695028, 0.039894000, 0.039695028, 0.039104044, 0.038138565, 0.036826804, 0.035206333, 0.033322271, 0.031225216)
#if Quality == 1
	float weight[MSIZE] = {0.031225216, 0.039894000, 0.031225216}; // by 3
#endif
#if Quality == 2
	float weight[MSIZE] = {0.031225216, 0.036826804, 0.039894000, 0.036826804, 0.031225216};  // by 5
#endif	
#if Quality == 3
	float weight[MSIZE] = {0.031225216, 0.035206333, 0.039104044, 0.039894000, 0.039104044, 0.035206333, 0.031225216};   // by 7
#endif
#if Quality == 4	
	float weight[MSIZE] = {0.031225216, 0.035206333, 0.038138565, 0.039695028, 0.039894000, 0.039695028, 0.038138565, 0.035206333, 0.031225216};  // by 9
#endif
	
		float3 final_colour;
		float Z;
		[unroll]
		for (int o = 0; o <= kSize; ++o)
		{
			weight[kSize+o] = normpdf(float(o), SIGMA);
			weight[kSize-o] = normpdf(float(o), SIGMA);
		}
		
		float3 cc;
		float factor;
		float bZ = rcp(normpdf(0.0, BSIGMA));
		
		[loop]
		for (int i=-kSize; i < kSize; ++i)
		{			
			cc = BB(texcoord.xy, float2( float(i) ,float(i) ) * pix * 0.5 );
			
			factor = normpdf3(cc-c, BSIGMA) * bZ * weight[kSize + i] * weight[kSize + i];
			Z += factor;
			final_colour += factor*cc;
		}
		
	float CAS_Mask = dot(ampRGB,float3(0.2126, 0.7152, 0.0722));

	if(CAS_Mask_Boost)
		CAS_Mask = lerp(CAS_Mask,CAS_Mask * CAS_Mask,saturate(Sharpness * 0.5));		
	
return saturate(float4(final_colour/Z,CAS_Mask));
}

float3 Sharpen_Out(float2 texcoord)                                                                          
{   float3 Done = BB(texcoord ,0);	
	return lerp(Done,Done+(Done - CAS(texcoord).rgb)*(Sharpness*3.), CAS(texcoord).w * saturate(Sharpness)); //Sharpen Out
}


float3 ShaderOut(float2 texcoord : TEXCOORD0)
{	
	float3 Out, Luma, Sharpen = Sharpen_Out(texcoord).rgb,BB = tex2D(BackBuffer,texcoord).rgb;
	float DB = Depth(texcoord).r,DBTL = Depth(float2(texcoord.x*2,texcoord.y*2)).r, DBBL = Depth(float2(texcoord.x*2,texcoord.y*2-1)).r;
	
	if(No_Depth_Map)
	{
		DB = 0.0;
		DBBL = 0.0;
	}
	
	if (Debug_View == 0)
	{			
		Out.rgb = lerp(Sharpen, BB, DB);
	}
	else if (Debug_View == 1)
	{
		float3 Top_Left = lerp(float3(1.,1.,1.),CAS(float2(texcoord.x*2,texcoord.y*2)).www,1-DBTL);
		
		float3 Top_Right =  Depth(float2(texcoord.x*2-1,texcoord.y*2)).rrr;		
		
		float3 Bottom_Left = lerp(float3(1., 0., 1.),tex2D(BackBuffer,float2(texcoord.x*2,texcoord.y*2-1)).rgb,DBBL);	

		float3 Bottom_Right = CAS(float2(texcoord.x*2-1,texcoord.y*2-1)).rgb;	
		
		float3 VA_Top = texcoord.x < 0.5 ? Top_Left : Top_Right ;
		float3 VA_Bottom = texcoord.x < 0.5 ? Bottom_Left : Bottom_Right ;
		
		Out = texcoord.y < 0.5 ? VA_Top : VA_Bottom;
	}
	else
		Out = Depth(texcoord);

	return Out;
}
uniform float timer < source = "timer"; >; //Please do not remove.
////////////////////////////////////////////////////////Logo/////////////////////////////////////////////////////////////////////////
float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float PosX = 0.9525f*BUFFER_WIDTH*pix.x,PosY = 0.975f*BUFFER_HEIGHT*pix.y;	
	float3 Color = ShaderOut(texcoord).rgb,D,E,P,T,H,Three,DD,Dot,I,N,F,O;
	
	[branch] if(timer <= 12500)
	{
		//DEPTH
		//D
		float PosXD = -0.035+PosX, offsetD = 0.001;
		float3 OneD = all( abs(float2( texcoord.x -PosXD, texcoord.y-PosY)) < float2(0.0025,0.009));
		float3 TwoD = all( abs(float2( texcoord.x -PosXD-offsetD, texcoord.y-PosY)) < float2(0.0025,0.007));
		D = OneD-TwoD;
		
		//E
		float PosXE = -0.028+PosX, offsetE = 0.0005;
		float3 OneE = all( abs(float2( texcoord.x -PosXE, texcoord.y-PosY)) < float2(0.003,0.009));
		float3 TwoE = all( abs(float2( texcoord.x -PosXE-offsetE, texcoord.y-PosY)) < float2(0.0025,0.007));
		float3 ThreeE = all( abs(float2( texcoord.x -PosXE, texcoord.y-PosY)) < float2(0.003,0.001));
		E = (OneE-TwoE)+ThreeE;
		
		//P
		float PosXP = -0.0215+PosX, PosYP = -0.0025+PosY, offsetP = 0.001, offsetP1 = 0.002;
		float3 OneP = all( abs(float2( texcoord.x -PosXP, texcoord.y-PosYP)) < float2(0.0025,0.009*0.775));
		float3 TwoP = all( abs(float2( texcoord.x -PosXP-offsetP, texcoord.y-PosYP)) < float2(0.0025,0.007*0.680));
		float3 ThreeP = all( abs(float2( texcoord.x -PosXP+offsetP1, texcoord.y-PosY)) < float2(0.0005,0.009));
		P = (OneP-TwoP) + ThreeP;

		//T
		float PosXT = -0.014+PosX, PosYT = -0.008+PosY;
		float3 OneT = all( abs(float2( texcoord.x -PosXT, texcoord.y-PosYT)) < float2(0.003,0.001));
		float3 TwoT = all( abs(float2( texcoord.x -PosXT, texcoord.y-PosY)) < float2(0.000625,0.009));
		T = OneT+TwoT;
		
		//H
		float PosXH = -0.0072+PosX;
		float3 OneH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.002,0.001));
		float3 TwoH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.002,0.009));
		float3 ThreeH = all( abs(float2( texcoord.x -PosXH, texcoord.y-PosY)) < float2(0.00325,0.009));
		H = (OneH-TwoH)+ThreeH;
		
		//Three
		float offsetFive = 0.001, PosX3 = -0.001+PosX;
		float3 OneThree = all( abs(float2( texcoord.x -PosX3, texcoord.y-PosY)) < float2(0.002,0.009));
		float3 TwoThree = all( abs(float2( texcoord.x -PosX3 - offsetFive, texcoord.y-PosY)) < float2(0.003,0.007));
		float3 ThreeThree = all( abs(float2( texcoord.x -PosX3, texcoord.y-PosY)) < float2(0.002,0.001));
		Three = (OneThree-TwoThree)+ThreeThree;	
		
		//DD
		float PosXDD = 0.006+PosX, offsetDD = 0.001;	
		float3 OneDD = all( abs(float2( texcoord.x -PosXDD, texcoord.y-PosY)) < float2(0.0025,0.009));
		float3 TwoDD = all( abs(float2( texcoord.x -PosXDD-offsetDD, texcoord.y-PosY)) < float2(0.0025,0.007));
		DD = OneDD-TwoDD;
		
		//Dot
		float PosXDot = 0.011+PosX, PosYDot = 0.008+PosY;		
		float3 OneDot = all( abs(float2( texcoord.x -PosXDot, texcoord.y-PosYDot)) < float2(0.00075,0.0015));
		Dot = OneDot;
		
		//INFO
		//I	
		float PosXI = 0.0155+PosX, PosYI = 0.004+PosY, PosYII = 0.008+PosY;
		float3 OneI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosY)) < float2(0.003,0.001));
		float3 TwoI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosYI)) < float2(0.000625,0.005));
		float3 ThreeI = all( abs(float2( texcoord.x - PosXI, texcoord.y - PosYII)) < float2(0.003,0.001));
		I = OneI+TwoI+ThreeI;
		
		//N
		float PosXN = 0.0225+PosX, PosYN = 0.005+PosY,offsetN = -0.001;
		float3 OneN = all( abs(float2( texcoord.x - PosXN, texcoord.y - PosYN)) < float2(0.002,0.004));
		float3 TwoN = all( abs(float2( texcoord.x - PosXN, texcoord.y - PosYN - offsetN)) < float2(0.003,0.005));
		N = OneN-TwoN;
		
		//F
		float PosXF = 0.029+PosX, PosYF = 0.004+PosY, offsetF = 0.0005, offsetF1 = 0.001;
		float3 OneF = all( abs(float2( texcoord.x -PosXF-offsetF, texcoord.y-PosYF-offsetF1)) < float2(0.002,0.004));
		float3 TwoF = all( abs(float2( texcoord.x -PosXF, texcoord.y-PosYF)) < float2(0.0025,0.005));
		float3 ThreeF = all( abs(float2( texcoord.x -PosXF, texcoord.y-PosYF)) < float2(0.0015,0.00075));
		F = (OneF-TwoF)+ThreeF;
		
		//O
		float PosXO = 0.035+PosX, PosYO = 0.004+PosY;
		float3 OneO = all( abs(float2( texcoord.x -PosXO, texcoord.y-PosYO)) < float2(0.003,0.005));
		float3 TwoO = all( abs(float2( texcoord.x -PosXO, texcoord.y-PosYO)) < float2(0.002,0.003));
		O = OneO-TwoO;
		//Website
		return float4(D+E+P+T+H+Three+DD+Dot+I+N+F+O,1.) ? 1-texcoord.y*50.0+48.35f : float4(Color,1.);
	}
	else
		return float4(Color,1.);
}

///////////////////////////////////////////////////////////ReShade.fxh/////////////////////////////////////////////////////////////

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

//*Rendering passes*//
technique Smart_Sharp
{		
			pass UnsharpMask
		{
			VertexShader = PostProcessVS;
			PixelShader = Out;	
		}
}