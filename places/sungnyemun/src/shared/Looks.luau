--!strict
-- 숭례문 노을·밤 색조 (core TimeOfDay가 해 높이에 따라 바꾼다). 낮 색조는 Studio의 Lighting·효과 값 그대로다.
-- 근사: 색 자료 없음. 노을은 주황·보라, 밤은 S15 사진처럼 짙은 남색 하늘. Studio에서 다듬은 값은 여기 옮겨 적는다.
local rgb = Color3.fromRGB

return {
	sunset = {
		Atmosphere = { Density = 0.36, Color = rgb(255, 168, 128), Decay = rgb(126, 82, 132), Glare = 0.6, Haze = 2 },
		ColorCorrectionEffect = { TintColor = rgb(255, 208, 170), Saturation = 0.2, Contrast = 0.08 },
		BloomEffect = { Intensity = 0.8, Size = 32, Threshold = 1.4 },
		SunRaysEffect = { Intensity = 0.12, Spread = 0.6 },
		Clouds = { Cover = 0.6, Density = 0.45, Color = rgb(255, 188, 170) },
	},
	night = {
		Atmosphere = { Density = 0.3, Color = rgb(52, 64, 104), Decay = rgb(24, 30, 62), Glare = 0, Haze = 1 },
		ColorCorrectionEffect = { TintColor = rgb(205, 214, 255), Saturation = -0.1, Contrast = 0.1, Brightness = -0.03 },
		BloomEffect = { Intensity = 1, Size = 24, Threshold = 1.2 },
		SunRaysEffect = { Intensity = 0 },
		Clouds = { Cover = 0.35, Density = 0.3, Color = rgb(64, 70, 96) },
	},
}
