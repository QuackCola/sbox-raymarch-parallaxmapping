//=========================================================================================================================
// Optional
//=========================================================================================================================
HEADER
{
	Description = "Example Parallax Occlusion Shader";
}

MODES
{
    VrForward();                                               // Indicates this shader will be used for main rendering
    ToolsVis( S_MODE_TOOLS_VIS );                              // Ability to see in the editor
    ToolsWireframe("vr_tools_wireframe.shader");               // Allows for mat_wireframe to work
    ToolsShadingComplexity("tools_shading_complexity.shader"); // Shows how expensive drawing is in debug view
}

//=========================================================================================================================
// Optional
//=========================================================================================================================
FEATURES
{
    #include "common/features.hlsl"
	//Feature(F_OUTPUT_TO_ALBEDO, 0..1, "Rendering");
}

//=========================================================================================================================
COMMON
{
	#include "common/shared.hlsl"
	#define S_UNLIT 1
	#define S_UV2 1
	#define VS_INPUT_HAS_TANGENT_BASIS 1
	#define PS_INPUT_HAS_TANGENT_BASIS 1
	#define CUSTOM_MATERIAL_INPUTS

	//
	// Parameters
	//
	float g_vSlices < UiType( Slider ); Default(25.0); Range(1,64); UiGroup( "Variables,10/20" ); >; // Limit it to a max of 64 slices.
	float g_vSliceDistance < UiType( Slider ); Default(0.15); Range(0.001,4); UiGroup( "Variables,10/21" ); >;
	float g_vTexCoordScale < UiType( Slider ); UiStep( 1 ); Default(1); Range(1,8); UiGroup( "Variables,10/21" ); >;
	float g_vEmissionStrength < UiType(Slider); Default (0.1); Range(0.1,8); UiGroup("Variables,10/20"); >;
}

//=========================================================================================================================

struct VertexInput
{
	#include "common/vertexinput.hlsl"
};

//=========================================================================================================================

struct PixelInput
{
	#include "common/pixelinput.hlsl"
	float3 vPositionOs : TEXCOORD14;
};

//=========================================================================================================================

VS
{
	#include "common/vertex.hlsl"
	//
	// Main
	//
	PixelInput MainVs( INSTANCED_SHADER_PARAMS( VertexInput i ) )
	{
		PixelInput o = ProcessVertex( i );
		// Add your vertex manipulation functions here	
		o.vPositionOs = i.vPositionOs.xyz;
		return FinalizeVertex( o );
	}
}

//=========================================================================================================================

PS
{

	//
	// Combos
	//
	//StaticCombo( S_OUTPUT_TO_ALBEDO, F_OUTPUT_TO_ALBEDO, Sys( ALL ) );

	// -------------------------------------------------------------------------------------------------------------------------------------------------------------

	//
	// Includes
	//
    #include "common/pixel.hlsl"

	// -------------------------------------------------------------------------------------------------------------------------------------------------------------

	//
	// Parameters
	//
	SamplerState g_sColorSampler< Filter( ANISO ); AddressU( WRAP ); AddressV( WRAP ); >;
	CreateInputTexture2D( Color, Srgb, 8, "None", "_color", "Color,0/,0/0", Default4( 1.00, 1.00, 1.00, 1.00 ) );
	Texture2D g_tColorMap < Channel( RGB, Box( Color ), Srgb ); OutputFormat( DXT5 ); SrgbRead( True ); >;
	SamplerState g_sHeightSampler< Filter( ANISO ); AddressU( WRAP ); AddressV( WRAP ); >;
	CreateInputTexture2D( Height, Srgb, 8, "None", "_height", "Height,0/,0/0", Default4( 1.00, 1.00, 1.00, 1.00 ) );
	Texture2D g_tHeightMap < Channel( RGB, Box( Height ), Srgb ); OutputFormat( DXT5 ); SrgbRead( True ); >;

	// -------------------------------------------------------------------------------------------------------------------------------------------------------------

	//
	// Functions
	//

	// TODO : Figure out what's causing the warping when the camera ( aka player ) gets close to the effect surface.

	float3 GetTangentViewVector( PixelInput i )
	{
		float3 vPositionWs = i.vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs.xyz;
        float3 vCameraToPositionDirWs = CalculateCameraToPositionDirWs( vPositionWs.xyz );
        float3 vNormalWs = normalize( i.vNormalWs.xyz );
        float3 vTangentUWs = i.vTangentUWs.xyz;
        float3 vTangentVWs = i.vTangentVWs.xyz;
       	float3 vTangentViewVector = Vec3WsToTs( vCameraToPositionDirWs.xyz, vNormalWs.xyz, vTangentUWs.xyz, vTangentVWs.xyz );
		
		// Result
		return vTangentViewVector;
	}

	float3 Raymarch(float2 vUV, float3 vViewDir, float3 vInputTex)
	{
		//float vRaystep = vViewDir * -1;
		// g_vSlices is the number of slices. Default is 25.0 
		// g_vSliceDistance is the distance between each slice. Default is 0.15 
		[loop]
		for(int i = 0; i < g_vSlices; i++)
		{
			if(vInputTex.r > 0.1 && vInputTex.g > 0.1 && vInputTex.b > 0.1)
			{
				// red value will increase with each slice.
				return float3(vInputTex.rgb);
				//return float3(cos(sin(g_flTime *i)),cos(sin(g_flTime *i)),0);
			}

				vUV += vViewDir * g_vSliceDistance;
    			vInputTex = Tex2DS(g_tHeightMap,g_sHeightSampler,vUV.xy);
		}

		// Raymarch Result
		return vInputTex;	
	}

	void MaterialSetup(PixelInput i)
	{	

	}

	//
	// Main
	//
	float4 MainPs( PixelInput i ) : SV_Target0
	{
		//
        // Multiview instancing
        //
        uint nView = uint(0);
        #if (D_MULTIVIEW_INSTANCING)
                nView = i.nView;
        #endif

		// Material Setup
		Material m;
		m.Albedo = float3( 0, 0, 0 );
		m.Normal = TransformNormal( i, float3( 0, 0, 1 ) );
		m.Roughness = 1;
		m.Metalness = 0;
		m.AmbientOcclusion = 0;
		m.TintMask = 1;
		m.Opacity = 1;
		m.Emission = float3( 0, 0, 0 );
		m.Transmission = 0;

		float2 vUV = i.vTextureCoords * g_vTexCoordScale;
		float3 vInputTex = Tex2DS(g_tHeightMap,g_sHeightSampler,vUV); // Texture Object
		float3 vTangentViewDir = normalize(GetTangentViewVector(i));
		//float3 vTangentViewDir = GetTangentViewVector(i);
		float3 vColorTex = Tex2DS(g_tColorMap,g_sColorSampler,vUV);
		

		// Result 
		m.Albedo = Raymarch(vUV,vTangentViewDir,vColorTex);
		m.Emission = Raymarch(vUV,vTangentViewDir,vInputTex) * g_vEmissionStrength;

		// make sure we are able to see the result in the editor when in fullbright or ingame when mat_fullbright is set to 1.
		#if S_MODE_TOOLS_VIS
            m.Albedo = m.Emission;
            m.Emission = 0;
        #endif

		return ShadingModelStandard::Shade( i, m );
	}
}
