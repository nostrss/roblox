--!strict
-- 숭례문 낮·노을·밤 색조 (core TimeOfDay가 해 높이에 따라 바꾼다).
-- 하늘은 tools/sky_cube.mjs로 구운 큐브맵이다. 노을 하늘의 해 쪽 빛은 ClockTime 17.6의 해 방향에 맞춰 구웠다.
-- 근사: 색 자료 없음. 노을은 주황·보라, 밤은 S15 사진처럼 짙은 남색 하늘. Studio에서 다듬은 값은 여기 옮겨 적는다.
local rgb = Color3.fromRGB

local function sky(bk: number, dn: number, ft: number, lf: number, rt: number, up: number): { [string]: any }
	local id = function(n: number): string
		return `rbxassetid://{n}`
	end
	return {
		SkyboxBk = id(bk), SkyboxDn = id(dn), SkyboxFt = id(ft), SkyboxLf = id(lf), SkyboxRt = id(rt), SkyboxUp = id(up),
	}
end

return {
	day = {
		Sky = sky(131040856752775, 91339032253636, 105286274660484, 122596059446236, 105329115457787, 98980534800019),
		Atmosphere = { Density = 0.14, Offset = 0.2, Color = rgb(205, 216, 228), Decay = rgb(120, 140, 170), Glare = 0.1, Haze = 0.6 },
		ColorCorrectionEffect = { TintColor = rgb(255, 252, 246), Saturation = 0.06, Contrast = 0.06, Brightness = 0 },
		BloomEffect = { Intensity = 0.35, Size = 24, Threshold = 2 },
		SunRaysEffect = { Intensity = 0.03, Spread = 0.3 },
		Lighting = { Brightness = 2.6, OutdoorAmbient = rgb(112, 118, 128), Ambient = rgb(70, 70, 72), ColorShift_Top = rgb(255, 244, 226), EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1 },
	},
	sunset = {
		Sky = sky(114896393031809, 71527512818271, 89180182483193, 101499414492525, 124433615626153, 74219837727272),
		Atmosphere = { Density = 0.16, Offset = 0.2, Color = rgb(255, 196, 150), Decay = rgb(170, 120, 130), Glare = 0.3, Haze = 0.5 },
		ColorCorrectionEffect = { TintColor = rgb(255, 240, 226), Saturation = 0.02, Contrast = 0.04, Brightness = 0 },
		BloomEffect = { Intensity = 0.7, Size = 32, Threshold = 1.6 },
		SunRaysEffect = { Intensity = 0.14, Spread = 0.5 },
		Lighting = { Brightness = 2.8, OutdoorAmbient = rgb(118, 100, 112), Ambient = rgb(70, 56, 60), ColorShift_Top = rgb(255, 176, 104), EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1 },
	},
	night = {
		Sky = sky(86784299708356, 122714494320281, 118226783766884, 140143608863262, 136165990408918, 109588160124256),
		Atmosphere = { Density = 0.14, Offset = 0.2, Color = rgb(58, 62, 96), Decay = rgb(30, 32, 66), Glare = 0, Haze = 0.6 },
		ColorCorrectionEffect = { TintColor = rgb(226, 230, 255), Saturation = 0, Contrast = 0.08, Brightness = 0.02 },
		BloomEffect = { Intensity = 0.9, Size = 24, Threshold = 1.3 },
		SunRaysEffect = { Intensity = 0 },
		Lighting = { Brightness = 1.4, OutdoorAmbient = rgb(62, 70, 96), Ambient = rgb(52, 54, 68), ColorShift_Top = rgb(160, 180, 230), EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.8 },
	},
}
