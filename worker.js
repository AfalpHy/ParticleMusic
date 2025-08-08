const { fileTypeFromFile } = require('file-type');
const { parseStream } = require('music-metadata');
const { parseFile } = require('music-metadata');
const { parentPort } = require('worker_threads');
const fs = require('fs');
const path = require('path');

let iconMIME;
let iconBase64String;
async function getAudioMetadata(filePath) {
    try {
        const stream = fs.createReadStream(filePath);
        const detected = await fileTypeFromFile(filePath);
        let metadata;
        if (detected.mime == 'audio/ogg') {
            metadata = await parseFile(filePath, { duration: true })
        } else {
            metadata = await parseStream(stream, detected.mime);
        }
        const picture = metadata.common.picture?.[0];
        let pictureMIME;
        let base64String
        if (picture) {
            pictureMIME = picture.format;
            base64String = Buffer.from(picture.data).toString('base64');
        } else {
            pictureMIME = iconMIME;
            base64String = iconBase64String;
        }
        return {
            filePath: filePath,
            coverDataUrl: `data:${pictureMIME};base64,${base64String}`,
            title: metadata.common.title ||
                path.basename(filePath, path.extname(filePath)),
            artist: metadata.common.artist || 'Unknown Artist',
            album: metadata.common.album || 'Unknown',
            duration: parseInt(metadata.format.duration)
        };
    } catch (error) {
        console.error('Error reading metadata:', error, filePath);
        return null;
    }
}

parentPort.on('message', async (data) => {
    iconMIME = 'image/png';
    iconBase64String = (await fs.promises.readFile(path.join(__dirname, 'pictures/icon.png'))).toString('base64');
    for (let i = data.id; i < data.songPaths.length; i += data.taskNum) {
        parentPort.postMessage(await getAudioMetadata(data.songPaths[i]));
    }
    process.exit(0);
});