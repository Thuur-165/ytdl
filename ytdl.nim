import std/[os, strutils]

# QOL Features:

# Ensure this program won't be run by double clicking
# NOTE: On Android, this program can only be run eith Termux or other terminal emulator
# NOTE: thus making this block useless, so by including `not defined(android) we increase performance
when not defined(android):
  import std/terminal
  if not isatty(stdin):
    echo "THIS PROGRAM IS NOT SUPPOSED TO BE DOUBLE CLICKED!!"
    sleep(2000)
    quit("Got clicked twice... :/", 1)

# End of QOL

let baseDir: string = getCurrentDir()
let outputDir: string = joinPath(baseDir, "ytdl") 

template ensureFullLink(rawInput: string): string =
    if len(rawInput) == 11 and "http" notin rawInput:
      "https://www.youtube.com/watch?v=$#" % rawInput
    else:
      rawInput

template moveDownloadedFiles(comeFrom: string, goTo: string) =
  echo "\n📦 \x1b[35mMoving files\x1b[m from ytdl/ to current directory..."
  try:
    for file in walkFiles(joinPath(comeFrom, "*")):
      let destPath = joinPath(goTo, extractFilename(file))
      moveFile(file, destPath)
      echo "✅ Moved: \x1b[32m", extractFilename(file), "\x1b[m"

    # Ou, se preferir escanear a pasta inteira de uma vez (mais eficiente):
    when defined(android):
      echo "🔄 \x1b[36mRefreshing media library\x1b[m..."
      discard execShellCmd("am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d \"file://" & goTo & "\"")
      
  except OSError as e:
    echo "❌ Error moving files: ", e.msg

proc downloadSong(url: string) =
  const outputPath: string = "%(title)s.%(ext)s"

  let command: string = "yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 " &
                "--embed-thumbnail --embed-metadata " &
                "--no-playlist --restrict-filenames " &
                "-o \"" & joinPath(outputDir, outputPath) & "\" " &
                "\"" & url & "\""
  
  echo "▶️  Downloading: ", url
  let exitCode: int = execShellCmd(command)
  
  if exitCode == 0:
    echo "✅ \x1b[32mSuccessfully downloaded\x1b[m: ", url, "\n"
  else:
    echo "❌ \x1b[31mError\x1b[m while downloading: ", url, " (code \x1b[36m", exitCode, "\x1b[m)\n"

proc processInput(input: string, moveAfter: bool = false) =

  setCurrentDir(baseDir)
  createDir(outputDir)

  # Tries to parse as file first
  var possibleFileNames: array[4, string] = [
    input,
    input & ".txt",
    changeFileExt(input, "") & ".txt",
    changeFileExt(input, "")
  ]

  for name in possibleFileNames:
    let path: string = joinPath(baseDir, name)
    echo "🔍 Verifying file: $#" % path

    # Verify if either files exists
    if fileExists(path):
      echo "✅ Found \"$#\"" % path
      # If found a valid file
      for rawLink in  open(path).readAll().split("\n"):
        # Parses and downloads the links correctly
        downloadSong(ensureFullLink(rawLink))

      if moveAfter:
        moveDownloadedFiles(outputDir, baseDir)
      quit(0)

  # But if didn't found any file
  echo "⚠️ \x1b[33mNo files were found\x1b[m: trying to treat as link or ID"
  downloadSong(ensureFullLink(input))

  if moveAfter:
    moveDownloadedFiles(outputDir, baseDir)

var moveAfter: bool = false
var inputArg: string = ""

# Checa argumentos simples
if paramCount() > 0:
  for i in 1..paramCount():
    let arg: string = paramStr(i)
    if arg == "--mv" or arg == "--move":
      moveAfter = true
    elif arg.len > 0 and arg[0] != '-':  # Se não começa com -, é o input
      inputArg = arg

if inputArg == "":
  write(stdout, "Input a \x1b[31mYouTube\x1b[m Video/Playlist ID, link or text file in this folder containing links or IDs\n\x1b[36m-->\x1b[m ")
  flushFile(stdout)
  inputArg = readLine(stdin).strip()

processInput(inputArg, moveAfter)
