 ////----------------//
 ///**Blooming HDR**///
 //----------------////

 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 //* HDR Bloom AKA FakeHDR + Bloom                                               																									*//
 //* For Reshade 3.0																																								*//
 //* --------------------------																																						*//
 //* This work is licensed under a Creative Commons Attribution 3.0 Unported License.																								*//
 //* So you are free to share, modify and adapt it for your needs, and even use it for commercial use.																				*//
 //* I would also love to hear about a project you are using it with.																												*//
 //* https://creativecommons.org/licenses/by/3.0/us/																																*//
 //*																																												*//
 //* Have fun,																																										*//
 //* Jose Negrete AKA BlueSkyDefender																																				*//
 //*																																												*//
 //* http://reshade.me/forum/shader-presentation/2128-sidebyside-3d-depth-map-based-stereoscopic-shader																				*//	
 //* ---------------------------------																																				*//
 //*                                                                            																									*//
 //* 																																												*//
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if !defined(__RESHADE__) || __RESHADE__ < 40000
	#define Compatibility 1
#else
	#define Compatibility 0
#endif

uniform float HDR_Adjust <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 0.5; ui_max = 2.0;
	ui_label = "HDR Likeness";
	ui_tooltip = "Use this to adjust HDR Likeness curve levels for your content.\n"
				"Number 1.250 is default.";
	ui_category = "HDR Adjustments";
> = 1.25;

uniform float CBT_Adjust <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Extracting Bright Colors";
	ui_tooltip = "Use this to set the color based brightness threshold for what is and what isn't allowed.\n"
				"This is the most important setting, use Debug View to adjust this.\n"
				"Number 0.5 is default.";
	ui_category = "Bloom Adjustments";
> = 0.5;

uniform bool Auto_Bloom_Intensity <
	ui_label = "Auto Bloom Intensity";
	ui_tooltip = "This will enable the shader to adjust Bloom Intensity automaticly.\n"
				 "You will need to adjust Bloom Intensity below during day light.";
	ui_category = "Bloom Adjustments";
> = true;

uniform float Bloom_Intensity<
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 0.0; ui_max = 2.0;
		ui_label = "Bloom Intensity";
	ui_tooltip = "Use this to set Bloom Intensity for your content.\n"
				"Number 0.3 is default.";
	ui_category = "Bloom Adjustments";
> = 0.3;

uniform float Saturation <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 0.0; ui_max = 5.0;
	ui_label = "Bloom Saturation";
	ui_tooltip = "Adjustment The amount to adjust the saturation of the color.\n"
				"Number 2.5 is default.";
	ui_category = "Bloom Adjustments";
> = 2.5;
 
uniform float Bloom_Spread_A <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 0.0; ui_max = 50.0; ui_step = 0.25;
	ui_label = "Bloom Spread";
	ui_tooltip = "Adjust This to have the Bloom effect Spread.\n"
				 "This is used for spreading Bloom.\n"
				 "Number 25.0 is default.";
	ui_category = "Bloom Adjustments";
> = 25.0;

uniform float Bloom_Spread_B <
	#if Compatibility
	ui_type = "drag";
	#else
	ui_type = "slider";
	#endif
	ui_min = 0.0; ui_max = 75.0; ui_step = 0.25;
	ui_label = "Bloom Spread+";
	ui_tooltip = "Adjust This to have the Bloom expand even more.\n"
				 "Number Zero is default.";
	ui_category = "Bloom Adjustments";
> = 0.0;

uniform int Luma_Coefficient <
	ui_type = "combo";
	ui_label = "Luma";
	ui_tooltip = "Changes how color get used for the other effects.\n";
	ui_items = "SD video\0HD video\0HDR video\0Intensity\0";
	ui_category = "Tonemapper Adjustments";
> = 1;

uniform float W <
	ui_type = "drag";
	ui_min = 0.00; ui_max = 20.00;
	ui_label = "Linear White Point Value";
	ui_category = "Tonemapper Adjustments";
> = 11.2;

uniform bool Auto_Exposure <
	ui_label = "Auto Exposure";
	ui_tooltip = "This will enable the shader to adjust Exposure automaticly.\n"
			 	"This will disable Exposure adjustment below.";
	ui_category = "Tonemapper Adjustments";
> = false;

uniform float Exp <
	ui_type = "drag";
	ui_min = 1.00; ui_max = 20.00;
	ui_label = "Exposure";
	ui_category = "Tonemapper Adjustments";
> = 1.0;

uniform float Gamma <
	ui_type = "drag";
	ui_min = 1.0; ui_max = 3.0;
	ui_label = "Gamma value";
	ui_tooltip = "Most monitors/images use a value of 2.2. Setting this to 1 disables the inital color space conversion from gamma to linear.";
	ui_category = "Tonemapper Adjustments";
> = 2.2;

uniform float Adapt_Adjust <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Eye Adapt Speed";
	ui_tooltip = "Use this to Adjust Eye Adaptation Speed.\n"
				 "Set from Zero to One, Zero is the slowest.\n"
				 "Number 0.5 is default.";
	ui_category = "Tonemapper Adjustments";
> = 0.5;

uniform int Debug_View <
	ui_type = "combo";
	ui_label = "Debug View";
	ui_items = "Normal View\0Bloom View\0";
	ui_tooltip = "To view Shade & Blur effect on the game, movie piture & ect.";
	ui_category = "Debugging";
	ui_category = "Tonemapper Adjustments";
> = 0;

/////////////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)

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
				
texture texMBlur_HVX { Width = BUFFER_WIDTH * 0.75; Height = BUFFER_HEIGHT *0.75; Format = RGBA16F; MipLevels = 2;};

sampler SamplerBlur_HVX
	{
		Texture = texMBlur_HVX;
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;	
	};	

texture texBloom { Width = BUFFER_WIDTH ; Height = BUFFER_HEIGHT ; Format = RGBA16F; MipLevels = 2;};

sampler SamplerBloom
	{
		Texture = texBloom;
		MinFilter = LINEAR;
		MagFilter = LINEAR;
		MipFilter = LINEAR;
	};
		
texture PastSingle_BackBuffer { Width = BUFFER_WIDTH ; Height = BUFFER_HEIGHT; Format = RGBA16F;};

sampler PSBackBuffer
	{
		Texture = PastSingle_BackBuffer;
	};
		
//Total amount of frames since the game started.
uniform uint framecount < source = "framecount"; >;	
uniform float frametime < source = "frametime";>;
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define Alternate framecount % 2 == 0  

float3 Luma()
{
	float3 Luma;
	
	if (Luma_Coefficient == 0)
	{
		Luma = float3(0.299, 0.587, 0.114); // (SD video)
	}
	else if (Luma_Coefficient == 1)
	{
		Luma = float3(0.2126, 0.7152, 0.0722); // (HD video) https://en.wikipedia.org/wiki/Luma_(video)
	}
	else if (Luma_Coefficient == 2)
	{
		Luma = float3(0.2627, 0.6780, 0.0593); // (HDR video) https://en.wikipedia.org/wiki/Rec._2100
	}
	else
	{
		Luma = float3(0.3333, 0.3333, 0.3333); // Intensity
	}
	return Luma;
}

/////////////////////////////////////////////////////////////////////////////////Adapted Luminance/////////////////////////////////////////////////////////////////////////////////
texture texLum {Width = 256; Height = 256; Format = R16F; MipLevels = 9;}; //Sample at 256x256 map only has nine mip levels; 0-1-2-3-4-5-6-7-8 : 256,128,64,32,16,8,4,2, and 1 (1x1).
																				
sampler SamplerLum																
	{
		Texture = texLum;
	};

texture texAvgLum { Format = R16F; };
																				
sampler SamplerAvgLum															
	{
		Texture = texAvgLum;
	};
	
texture2D TexAvgLumaLast { Format = R16F; };
sampler SamplerAvgLumaLast { Texture = TexAvgLumaLast; };	
	
float Luminance(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target	
{   
	return dot(tex2D(BackBuffer,texcoord).rgb, Luma());
}

float Average_Luminance(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target	
{
	float AA = 1-Adapt_Adjust, L =  tex2Dlod(SamplerLum,float4(texcoord,0,11)).x, PL = tex2D(SamplerAvgLumaLast, texcoord).x;
	//Temporal adaptation https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/
 
	return PL + (L - PL) * (1.0 - exp(-frametime/(AA*1000)));   	
}
   
//////////////////////////////////////////////////////////////	/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

float3 Bright_Colors(float2 texcoords)
{   
	float A = 1-tex2D(SamplerAvgLum,0.0).x, BI = Bloom_Intensity, NC = smoothstep(0,1,A);
    float2 tex_offset = (Bloom_Spread_A * 0.25) * pix; // Gets texel offset
	
	NC = saturate(NC - 0.5);
     	
	if(Auto_Bloom_Intensity)
	{
		BI = Bloom_Intensity;
		BI *= NC;
	}

	float3 BC = tex2D(BackBuffer, texcoords).rgb;
	
	// check whether fragment output is higher than threshold, if so output as brightness color.
    float brightness = dot(BC.rgb, Luma());
    
    if(brightness > CBT_Adjust)
        BC.rgb = BC.rgb;
    else
        BC.rgb = float3(0.0, 0.0, 0.0);
	
	float3 intensity = dot(BC.rgb,Luma());
    BC.rgb = lerp(intensity,BC.rgb,Saturation);  
	// The result of the bright-pass filter is then downscaled.
	return BC * BI;	
}

float3 MBlur_HV(float2 texcoords )
{   //Post Blur Using Mips
	int TM;
	float2 tex_offset = Bloom_Spread_A  * pix; // Gets texel offset
	
	if (Alternate)
	{
		TM = 1;
		tex_offset *= 0.5;
	}
	
	float3 PB = Bright_Colors(texcoords).rgb;
	//H	
	PB += Bright_Colors(texcoords + float2( 0.75, 0) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.75, 0) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0.5 , 0) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.5 , 0) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0.25, 0) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.25, 0) * tex_offset).rgb;
	//V
	PB += Bright_Colors(texcoords + float2( 0, 0.75) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0,-0.75) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0, 0.5 ) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0,-0.5 ) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0, 0.25) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0,-0.25) * tex_offset).rgb;
	return PB / 13;	
}

float3 MBlur_X(float2 texcoords ) 
{   //Post Blur Using Mips
	int TM;
	float2 tex_offset = Bloom_Spread_A * pix; // Gets texel offset
	
	if (Alternate)
	{
		TM = 1;
		tex_offset *= 0.5;
	}
			
	float3 PB = Bright_Colors(texcoords).rgb;
	PB += Bright_Colors(texcoords + float2( 0.75, 0.75) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.75,-0.75) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0.75,-0.75) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.75, 0.75) * tex_offset).rgb;
	
	PB += Bright_Colors(texcoords + float2( 0.5, 0.5 ) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.5,-0.5 ) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0.5,-0.5 ) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.5, 0.5 ) * tex_offset).rgb;
	
	PB += Bright_Colors(texcoords + float2( 0.25, 0.25) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.25,-0.25) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2( 0.25,-0.25) * tex_offset).rgb;
	PB += Bright_Colors(texcoords + float2(-0.25, 0.25) * tex_offset).rgb;
	
	return PB / 13;
}

float3 CombBlur_HVX(float4 position : SV_Position, float2 texcoords : TEXCOORD) : SV_Target 
{
   return lerp(MBlur_X(texcoords),MBlur_HV(texcoords),0.5);
}

float3 LastBlur(float2 texcoords : TEXCOORD0)
{
	int TM;
	float BSA = 1 + (Bloom_Spread_A * 0.02);	
	float2 tex_offset = 8.75 * BSA * pix; // Gets texel offset
	float3 result = tex2Dlod(SamplerBlur_HVX, float4(texcoords,0,0)).rgb;
		
	if (Alternate)
	{
		TM = 1;
		tex_offset *= 0.5;
	}
			
		//xBlur
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2( 0.75, 0.75) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2(-0.75,-0.75) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2( 0.75,-0.75) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2(-0.75, 0.75) * tex_offset, 0, 0 + TM)).rgb;
		
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2( 0.5, 0.5) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2(-0.5,-0.5) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2( 0.5,-0.5) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2(-0.5, 0.5) * tex_offset, 0, 0 + TM)).rgb;
		
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2( 0.25, 0.25) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2(-0.25,-0.25) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2( 0.25,-0.25) * tex_offset, 0, 0 + TM)).rgb;
		result += tex2Dlod(SamplerBlur_HVX, float4(texcoords + float2(-0.25, 0.25) * tex_offset, 0, 0 + TM)).rgb;

   return result / 13;
}

float4 Mix_Bloom(float4 position : SV_Position, float2 texcoords : TEXCOORD) : SV_Target//Then blurred.                                                                        
{  
	return float4(LastBlur(texcoords) + tex2D(PSBackBuffer, texcoords).rgb,1.); // Merge Current and past frame.
}

float3 HableTonemap(float3 x)
{
	float A,B,C,D,E,F;
	A = 0.22f;
	B = 0.30f;
	C = 0.10f;
	D = 0.20f;
	E = 0.01f;
	F = 0.22f;
   return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

float4 HDROut(float2 texcoords : TEXCOORD0)
{	
	float A = 1-tex2D(SamplerAvgLum,0.0).x, Ex = Exp, BSA = (Bloom_Spread_A * 0.02);
	float2 tex_offset = (Bloom_Spread_B * BSA) * pix; // Gets texel offset
	//Blur+ Acculimation 
	float3 acc = tex2Dlod(SamplerBloom,float4(texcoords,0, BSA)).rgb;
	//H
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 1.0 , 0) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2(-1.0 , 0) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0.5, 0) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2(-0.5, 0) * tex_offset,0, BSA)).rgb;
	//V
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0, 1.0 ) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0,-1.0 ) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0, 0.5) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0,-0.5) * tex_offset,0, BSA)).rgb;
	//X 1
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0.75, 0.75 ) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2(-0.75,-0.75 ) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0.75,-0.75 ) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2(-0.75, 0.75 ) * tex_offset,0, BSA)).rgb;
	//X 2
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0.5, 0.5) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2(-0.5,-0.5) * tex_offset,0, BSA)).rgb;	
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0.5,-0.5) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2(-0.5, 0.5) * tex_offset,0, BSA)).rgb;
	//X 3
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0.25, 0.25 ) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2(-0.25,-0.25 ) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2( 0.25,-0.25 ) * tex_offset,0, BSA)).rgb;
	acc += tex2Dlod(SamplerBloom,float4(texcoords + float2(-0.25, 0.25 ) * tex_offset,0, BSA)).rgb;
	
	acc /= 21;
		
	float4 Out;
    float3 TM, Color = tex2D(BackBuffer, texcoords).rgb, Bloom = acc.rgb, bloomColor = acc.rgb;
	// Do inital de-gamma of the game image to ensure we're operating in the correct colour range.
	if( Gamma > 1.00 )
		Color = pow(abs(Color),Gamma);

	//Add Bloom
	Color += bloomColor;

	//Tone map all the things	
	if(Auto_Exposure)
		Ex = A * 1.125;
	//UTM		
	Color *= Ex;  // Exposure Adjustment

	float ExposureBias = 2.0f;
	float3 curr;
	
	float3 lum = Luma().x * Color.r + Luma().y * Color.g + Luma().z * Color.b;
	float3 newLum = HableTonemap(ExposureBias*lum);
	float3 lumScale = newLum / lum;
	curr = Color*lumScale;

	float3 whiteScale = 1.0f/HableTonemap(W);
	
	Color = curr*whiteScale;
    
	// Do the post-tonemapping gamma correction
	if( Gamma > 1.00 )
		Color = pow(abs(Color),1/Gamma);


	//FAKE HDR CuRv to piss off TrayM in a good way <3
	Color = pow(abs(Color),HDR_Adjust) + (Color * 0.5);

	if (Debug_View == 0)
		Out = float4(Color, 1.0);
	else if(Debug_View == 1)
		Out = float4(Bloom, 1.0);	
		
	return Out;
}

float4 Past_BackSingleBuffer(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{	
	 return float4(LastBlur(texcoord),1.0);
}

float PS_StoreAvgLuma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2D(SamplerAvgLum,texcoord).x;
}

uniform float timer < source = "timer"; >;
////////////////////////////////////////////////////////Logo/////////////////////////////////////////////////////////////////////////
float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float PosX = 0.9525f*BUFFER_WIDTH*pix.x,PosY = 0.975f*BUFFER_HEIGHT*pix.y;	
	float3 Color = HDROut(texcoord).rgb,D,E,P,T,H,Three,DD,Dot,I,N,F,O;
	
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
technique Blooming_HDR
{	
		pass MIP_Blur_HVX
	{
		VertexShader = PostProcessVS;
		PixelShader = CombBlur_HVX;
		RenderTarget = texMBlur_HVX;
	}
		pass Temporal_Mixing_Bloom
	{
		VertexShader = PostProcessVS;
		PixelShader = Mix_Bloom;
		RenderTarget = texBloom;
	}
		pass Lum
    {
        VertexShader = PostProcessVS;
        PixelShader = Luminance;
        RenderTarget = texLum;
    }
    	pass Avg_Lum
    {
        VertexShader = PostProcessVS;
        PixelShader = Average_Luminance;
        RenderTarget = texAvgLum;
    }
	    
		pass HDROut
	{
		VertexShader = PostProcessVS;
		PixelShader = Out;	
	}
		pass PSB
	{
		VertexShader = PostProcessVS;
		PixelShader = Past_BackSingleBuffer;
		RenderTarget = PastSingle_BackBuffer;	
	}
	
	  pass StoreAvgLuma
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_StoreAvgLuma;
        RenderTarget = TexAvgLumaLast;
    }	
	
}
