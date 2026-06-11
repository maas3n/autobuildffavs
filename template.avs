# Enable debugging and log all errors to home directory
SetLogParams("/home/YOURUSERNAME/AviSynthPlusdebug.log", 4)
#
# Load your source plugin explicitly if not autoloaded
LoadPlugin("/usr/local/lib/libffms2.so")
# Load your native Linux yadifmod2 plugin
LoadPlugin("/usr/local/lib/avisynth/libyadifmod2.so")
#
# Open your video file using FFMS2
FFVideoSource("/home/YOURUSERNAME/input.mkv")
# Cut for test encode
Trim(7200, 7272)
# Deinterlace
# (mode=1, order=1) If your video is top field first
# (mode=1, order=0) If your video is bottom field first
Yadifmod2(mode=1, order=1)
# Crop
Crop(2, 2, -2, -2)
# Resize
Spline36Resize(1024, 576)
