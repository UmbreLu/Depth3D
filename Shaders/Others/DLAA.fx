 ////--------//
 ///**DLAA**///
 //--------////

 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 //* Directionally localized antialiasing.
 //* For Reshade 3.0
 //* --------------------------
 //* This work is licensed under a Creative Commons Attribution 3.0 Unported License.
 //* So you are free to share, modify and adapt it for your needs, and even use it for commercial use.
 //* I would also love to hear about a project you are using it with.
 //* https://creativecommons.org/licenses/by/3.0/us/
 //*
 //* Have fun,
 //* Jose Negrete AKA BlueSkyDefender
 //*
 //* http://and.intercon.ru/releases/talks/dlaagdc2011/
 //* ---------------------------------
 //*
 //* Directionally Localized Anti-Aliasing (DLAA)
 //* Original method by Dmitry Andreev - Copyright (C) LucasArts 2010-2011
 //*
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 uniform float Short_Edge_Mask <
 	ui_type = "drag";
 	ui_min = 0.0; ui_max = 1.0;
 	ui_label = "Short Edge AA";
 	ui_tooltip = "Use this to adjust the Long Edge AA.\n"
 				 "Default is 0.2";
 	ui_category = "DLAA";
 > = 0.5;

uniform float Long_Edge_Mask <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Long Edge AA";
	ui_tooltip = "Use this to adjust the Long Edge AA.\n"
				 "Default is 0.2";
	ui_category = "DLAA";
> = 0.5;

uniform float Super_Long_Edge_Mask_H <
	ui_type = "drag";
	ui_min = 1.0; ui_max = 10.0;
	ui_label = "Super Long Edge H";
	ui_tooltip = "Use this to adjust the Super Long Edge AA.\n"
				 "Default is 1.0";
	ui_category = "DLAA Expanded";
> = 1.0;

uniform float Super_Long_Edge_Mask_V <
	ui_type = "drag";
	ui_min = 1.0; ui_max = 10.0;
	ui_label = "Super Long Edge V";
	ui_tooltip = "Use this to adjust the Super Long Edge AA.\n"
				 "Default is 1.0";
	ui_category = "DLAA Expanded";
> = 1.0;

 uniform float Error_Clamping <
 	ui_type = "drag";
 	ui_min = 0.0; ui_max = 1.0;
 	ui_label = "Error Clamping";
 	ui_tooltip = "Use this to adjust little edge error clamping.\n"
 				 "Default is 0.25";
 	ui_category = "DLAA Debuging";
 > = 0.25;

uniform int View_Mode <
	ui_type = "combo";
	ui_items = "DLAA Out\0Short Edge Mask\0Long Edge Mask\0";
	ui_label = "View Mode";
	ui_tooltip = "This is used to select the normal view output or debug view.";
	ui_category = "DLAA Debuging";
> = 0;

//Total amount of frames since the game started.
uniform uint framecount < source = "framecount"; >;
////////////////////////////////////////////////////////////DLAA////////////////////////////////////////////////////////////////////
#define Alternate framecount % 2 == 0
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)
#define lambda lerp(0,10,Short_Edge_Mask)
#define epsilon lerp(0,0.5,Error_Clamping)

texture BackBufferTex : COLOR;

sampler BackBuffer
	{
		Texture = BackBufferTex;
	};
texture SLPtex_H {Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };

sampler SamplerLoadedPixel_H
	{
		Texture = SLPtex_H;
	};

  texture TexDLAA_H {Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };

  sampler SamplerDLAA_H
  	{
  		Texture = TexDLAA_H;
  	};

  texture SLPtex_V {Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };

  sampler SamplerLoadedPixel_V
  	{
  		Texture = SLPtex_V;
  	};
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//Luminosity Intensity
float LI(in float3 value)
{
	//Luminosity Controll from 0.1 to 1.0
	//If GGG value of 0.333, 0.333, 0.333 is about right for Green channel.
	//Slide 51 talk more about this.
	return dot(value.rgb,float3(0.299, 0.587, 0.114));
}

float4 LP_H(float2 tc,float dx, float dy) //Load Pixel
{
float4 BB = tex2D(BackBuffer, tc + float2(dx, dy) * pix.xy);
return BB;
}

float4 PreFilter_H(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target //Loaded Pixel
{

    float4 center = LP_H(texcoord,  0,  0);
    float4 left   = LP_H(texcoord, -0.5 ,  0);
    float4 right  = LP_H(texcoord,  0.5,  0);
    float4 top    = LP_H(texcoord,  0, -0.5);
    float4 bottom = LP_H(texcoord,  0,  0.5);

    float4 edges = 4.0 * abs((left + right + top + bottom) - 4.0 * center);
    float  edgesLum = LI(edges.rgb);

    return float4(center.rgb, edgesLum);
}

float4 SLP_H(float2 tc,float dx, float dy) //Load Pixel
{
	float4 BB = tex2D(SamplerLoadedPixel_H, tc + float2(dx, dy) * pix.xy);
	return BB;
}

//Information on Slide 44 says to run the edge processing jointly short and Large.
float4 DLAA_H(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target //Loaded Pixel
{
	//Short Edge Filter http://and.intercon.ru/releases/talks/dlaagdc2011/slides/#slide43
	float4 DLAA, DLAA_L, H, V, UDLR; //DLAA is the completed AA Result.
  float SLE_H = 2 * Super_Long_Edge_Mask_H;
	//5 bi-linear samples cross
	float4 Center = SLP_H(texcoord, 0 , 0);
	float4 Left   = SLP_H(texcoord,-1.25 , 0.0);
	float4 Right  = SLP_H(texcoord, 1.25 , 0.0);
	float4 Up     = SLP_H(texcoord, 0.0 ,-1.25);
	float4 Down   = SLP_H(texcoord, 0.0 , 1.25);


	//Combine horizontal and vertical blurs together
	float4 combH		= 2.0 * ( Left + Right );
	float4 combV		= 2.0 * ( Up + Down );

	//Bi-directional anti-aliasing using HORIZONTAL & VERTICAL blur and horizontal edge detection
	//Slide information triped me up here. Read slide 43.
	//Edge detection
	float4 CenterDiffH	= abs( combH - 4.0 * Center ) / 4.0;
	float4 CenterDiffV	= abs( combV - 4.0 * Center ) / 4.0;

	//Blur
	float4 blurredH		= (combH + 2.0 * Center) / 6.0;
	float4 blurredV		= (combV + 2.0 * Center) / 6.0;

	//Edge detection
	float LumH			= LI( CenterDiffH.rgb );
	float LumV			= LI( CenterDiffV.rgb );

	float LumHB = LI(blurredH.xyz);
    float LumVB = LI(blurredV.xyz);

	//t
	float satAmountH 	= saturate( ( lambda * LumH - epsilon ) / LumVB );
	float satAmountV 	= saturate( ( lambda * LumV - epsilon ) / LumHB );

	//color = lerp(color,blur,sat(Edge/blur)
	//Re-blend Short Edge Done
	DLAA = lerp( Center, blurredH, satAmountV * 1.1 );
	DLAA = lerp( DLAA,   blurredV, satAmountH * 0.5);

	float4  HNeg, HNegA, HNegB, HNegC, HNegD, HNegE,
    			HPos, HPosA, HPosB, HPosC, HPosD, HPosE,
    			VNeg, VNegA, VNegB, VNegC,
    			VPos, VPosA, VPosB, VPosC;

  // Long Edges
  //16 bi-linear samples cross, added extra bi-linear samples in each direction.
  HNeg    = Left;
  HNegA   = SLP_H( texcoord, -3.5 , 0.0 );
  HNegB   = SLP_H( texcoord, -5.5 , 0.0 );
  HNegC   = SLP_H( texcoord, -7.0 , 0.0 );

  HPos    = Right;
  HPosA   = SLP_H( texcoord,  3.5 , 0.0 );
  HPosB   = SLP_H( texcoord,  5.5 , 0.0 );
  HPosC   = SLP_H( texcoord,  7.0 , 0.0 );

  VNeg    = Up;
  VNegA   = SLP_H( texcoord,  0.0,-3.5  );
  VNegB   = SLP_H( texcoord,  0.0,-5.5  );
  VNegC   = SLP_H( texcoord,  0.0,-7.0  );

  VPos    = Down;
  VPosA   = SLP_H( texcoord,  0.0, 3.5  );
  VPosB   = SLP_H( texcoord,  0.0, 5.5  );
  VPosC   = SLP_H( texcoord,  0.0, 7.0  );

  //Long Edge detection H & V
  float4 AvgBlurH = ( HNeg + HNegA + HNegB + HNegC + HPos + HPosA + HPosB + HPosC ) / 8;
  float4 AvgBlurV = ( VNeg + VNegA + VNegB + VNegC + VPos + VPosA + VPosB + VPosC ) / 8;
	float EAH = saturate( AvgBlurH.a * SLE_H - 1.0 );
	float EAV = saturate( AvgBlurV.a * 2.0 - 1.0 );

  float longEdge_H = abs( EAH - EAV );

  float Mask_H = longEdge_H > 1-Long_Edge_Mask;
	
	DLAA_L = DLAA;
	
    if ( Mask_H )
    {
      float4 up    = LP_H(texcoord, 0 ,-1);
      float4 down  = LP_H(texcoord, 0 , 1);
      //Merge for BlurSamples.
      //Long Blur H
      float LongBlurLumH = LI( AvgBlurH.rgb);

      float centerLI = LI( Center.rgb );
      float upLI     = LI( up.rgb );
      float downLI   = LI( down.rgb );

      float blurUp = saturate( 0.0 + ( LongBlurLumH - upLI    ) / (centerLI - upLI) );
      float blurDown = saturate( 1.0 + ( LongBlurLumH - centerLI ) / (centerLI - downLI) );

      UDLR = float4( 1, 1, blurUp, blurDown );

      UDLR = UDLR == float4(0.0, 0.0, 0.0, 0.0) ? float4(1.0, 1.0, 1.0, 1.0) : UDLR;

      H = lerp( up   , Center, UDLR.z );
      H = lerp( down , H	 , UDLR.w );

      //Reuse short samples and DLAA Long Edge Out.
      DLAA_L = lerp( DLAA , H , EAH);
    }
	
	DLAA = lerp(DLAA, DLAA_L, 1 );

	//if(View_Mode == 1)
	//{
	//	DLAA = lerp(DLAA,float4(1,1,0,1),abs(satAmountH-satAmountV) * 2);
	//}
	//else if (View_Mode == 2)
	//{
	//	DLAA = lerp(DLAA,float4(1,0,0,1),saturate(EAV));
	//}

	return DLAA;
}

float4 LP_V(float2 tc,float dx, float dy) //Load Pixel
{
float4 BB = tex2D(SamplerDLAA_H, tc + float2(dx, dy) * pix.xy);
return BB;
}

float4 PreFilter_V(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target //Loaded Pixel
{

    float4 center = LP_V(texcoord,  0,  0);
    float4 left   = LP_V(texcoord, -0.5 ,  0);
    float4 right  = LP_V(texcoord,  0.5,  0);
    float4 top    = LP_V(texcoord,  0, -0.5);
    float4 bottom = LP_V(texcoord,  0,  0.5);

    float4 edges = 4.0 * abs((left + right + top + bottom) - 4.0 * center);
    float  edgesLum = LI(edges.rgb);

    return float4(center.rgb, edgesLum);
}

float4 SLP_V(float2 tc,float dx, float dy) //Load Pixel
{
	float4 BB = tex2D(SamplerLoadedPixel_V, tc + float2(dx, dy) * pix.xy);
	return BB;
}

float4 DLAA_V(float2 texcoord)
{
	//Short Edge Filter http://and.intercon.ru/releases/talks/dlaagdc2011/slides/#slide43
	float4 DLAA, DLAA_L, H, V, UDLR; //DLAA is the completed AA Result.
  float SLE_V = 2 * Super_Long_Edge_Mask_V;
	//5 bi-linear samples cross
	float4 Center = SLP_V(texcoord, 0 , 0);
	float4 Left   = SLP_V(texcoord,-1.25 , 0.0);
	float4 Right  = SLP_V(texcoord, 1.25 , 0.0);
	float4 Up     = SLP_V(texcoord, 0.0 ,-1.25);
	float4 Down   = SLP_V(texcoord, 0.0 , 1.25);

	//Combine horizontal and vertical blurs together
	float4 combH		= 2.0 * ( Left + Right );
	float4 combV		= 2.0 * ( Up + Down );

	//Bi-directional anti-aliasing using HORIZONTAL & VERTICAL blur and horizontal edge detection
	//Slide information triped me up here. Read slide 43.
	//Edge detection
	float4 CenterDiffH	= abs( combH - 4.0 * Center ) / 4.0;
	float4 CenterDiffV	= abs( combV - 4.0 * Center ) / 4.0;

	//Blur
	float4 blurredH		= (combH + 2.0 * Center) / 6.0;
	float4 blurredV		= (combV + 2.0 * Center) / 6.0;

	//Edge detection
	float LumH			= LI( CenterDiffH.rgb );
	float LumV			= LI( CenterDiffV.rgb );

	float LumHB = LI(blurredH.xyz);
  float LumVB = LI(blurredV.xyz);

	//t
	float satAmountH 	= saturate( ( lambda * LumH - epsilon ) / LumVB );
	float satAmountV 	= saturate( ( lambda * LumV - epsilon ) / LumHB );

	//color = lerp(color,blur,sat(Edge/blur)
	//Re-blend Short Edge Done
	DLAA = lerp( Center, blurredH, satAmountV * 1.1 );
	DLAA = lerp( DLAA,   blurredV, satAmountH * 0.5);

	float4  HNeg, HNegA, HNegB, HNegC, HNegD, HNegE,
          HPos, HPosA, HPosB, HPosC, HPosD, HPosE,
          VNeg, VNegA, VNegB, VNegC,
          VPos, VPosA, VPosB, VPosC;

	  // Long Edges
    //16 bi-linear samples cross, added extra bi-linear samples in each direction.
    HNeg    = Left;
    HNegA   = SLP_V( texcoord, -3.5 , 0.0 );
    HNegB   = SLP_V( texcoord, -5.5 , 0.0 );
    HNegC   = SLP_V( texcoord, -7.0 , 0.0 );

    HPos    = Right;
    HPosA   = SLP_V( texcoord,  3.5 , 0.0 );
    HPosB   = SLP_V( texcoord,  5.5 , 0.0 );
    HPosC   = SLP_V( texcoord,  7.0 , 0.0 );

    VNeg    = Up;
    VNegA   = SLP_V( texcoord,  0.0,-3.5  );
    VNegB   = SLP_V( texcoord,  0.0,-5.5  );
    VNegC   = SLP_V( texcoord,  0.0,-7.0  );

    VPos    = Down;
    VPosA   = SLP_V( texcoord,  0.0, 3.5  );
    VPosB   = SLP_V( texcoord,  0.0, 5.5  );
    VPosC   = SLP_V( texcoord,  0.0, 7.0  );

    //Long Edge detection H & V
    float4 AvgBlurH = ( HNeg + HNegA + HNegB + HNegC + HPos + HPosA + HPosB + HPosC ) / 8;
    float4 AvgBlurV = ( VNeg + VNegA + VNegB + VNegC + VPos + VPosA + VPosB + VPosC ) / 8;
    float EAH = saturate( AvgBlurH.a * 2.0 - 1.0 );
    float EAV = saturate( AvgBlurV.a * SLE_V - 1.0 );

    float longEdge_V = abs( EAV - saturate( AvgBlurH.a * 2.0 - 1.0 ) );

    float Mask_V = longEdge_V > 1-Long_Edge_Mask;
    
	DLAA_L = DLAA;
	
    if ( Mask_V )
    {
      float4 left  = LP_V(texcoord,-1 , 0);
      float4 right = LP_V(texcoord, 1 , 0);
      //Merge for BlurSamples.

      //Long Blur V
      float LongBlurLumV = LI( AvgBlurV.rgb );

      float centerLI = LI( Center.rgb );
      float leftLI   = LI( left.rgb );
      float rightLI  = LI( right.rgb );

      float blurLeft = saturate( 0.0 + ( LongBlurLumV - leftLI   ) / (centerLI - leftLI) );
      float blurRight = saturate( 1.0 + ( LongBlurLumV - centerLI ) / (centerLI - rightLI) );

      UDLR = float4( blurLeft, blurRight, 1, 1 );

      UDLR = UDLR == float4(0.0, 0.0, 0.0, 0.0) ? float4(1.0, 1.0, 1.0, 1.0) : UDLR;

      V = lerp( left , Center, UDLR.x );
      V = lerp( right, V	 , UDLR.y );

      //Reuse short samples and DLAA Long Edge Out.
      DLAA_L = lerp( DLAA , V , EAV);
    }
    
	DLAA = lerp(DLAA, DLAA_L, 1 );
    	
    return DLAA;
}

float4 DLAA(float2 texcoord)
{
	return DLAA_V(texcoord);
}

uniform float timer < source = "timer"; >; //Please do not remove.
////////////////////////////////////////////////////////Logo/////////////////////////////////////////////////////////////////////////
float4 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float PosX = 0.9525f*BUFFER_WIDTH*pix.x,PosY = 0.975f*BUFFER_HEIGHT*pix.y;
	float3 Color = DLAA(texcoord).rgb,D,E,P,T,H,Three,DD,Dot,I,N,F,O;

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

///////////////ReShade.fxh/////////////////////////////////////////////////////////////

// Vertex shader generating a triangle covering the entire screen
void PostProcessVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
	texcoord.x = (id == 2) ? 2.0 : 0.0;
	texcoord.y = (id == 1) ? 2.0 : 0.0;
	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

//*Rendering passes*//
technique Directionally_Localized_Anti_Aliasing
{
			pass Pre_Filter_Hoizontal
		{
			VertexShader = PostProcessVS;
			PixelShader = PreFilter_H;
			RenderTarget = SLPtex_H;
		}
      pass Pre_Filter_Vertical
    {
      VertexShader = PostProcessVS;
      PixelShader = DLAA_H;
      RenderTarget = TexDLAA_H;
    }
      pass Pre_Filter_Vertical
    {
      VertexShader = PostProcessVS;
      PixelShader = PreFilter_V;
      RenderTarget = SLPtex_V;
    }
			pass DLAA
		{
			VertexShader = PostProcessVS;
			PixelShader = Out;
		}
}
