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
        let metadata;
        const detected = await fileTypeFromFile(filePath);
        if (detected.mime == 'audio/ogg') {
            metadata = await parseFile(filePath, { duration: true });
        } else if (detected.mime == 'audio/aac') {
            const stream = fs.createReadStream(filePath);
            metadata = await parseStream(stream, detected.mime);
        } else {
            metadata = await parseFile(filePath);
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
        let artistStr = 'Unknown';
        if (metadata.common.artists) {
            metadata.common.artists.forEach(element => {
                if (artistStr == 'Unknown')
                    artistStr = element;
                else
                    artistStr += '/' + element
            });
        }
        return {
            filePath: filePath,
            coverDataUrl: `data:${pictureMIME};base64,${base64String}`,
            title: metadata.common.title ||
                path.basename(filePath, path.extname(filePath)),
            artist: artistStr,
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