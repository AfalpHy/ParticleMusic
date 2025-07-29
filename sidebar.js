import { shared } from "./shared.js";
import { playbackQueue } from "./shared.js";
import { formatTime } from "./shared.js";

let metaIndex = 1;
window.electronAPI.receiveSongMetadata((metadata) => {
    shared.playlist.push(metadata);
    let message = [
        metaIndex++, metadata.title, metadata.artist, metadata.album,
        formatTime(metadata.duration)
    ];
    const songLabelChidren = document.getElementById('song-label').children;

    const lineElement = document.createElement('div');
    lineElement.className = 'song-line';

    for (let i = 0; i < message.length; i++) {
        const columnElement = document.createElement('div');
        columnElement.className = songLabelChidren[i].className;
        columnElement.style.flex = songLabelChidren[i].style.flex;
        columnElement.style.overflow = 'hidden';

        const columnElementText = document.createElement('div');
        columnElementText.className = 'song-line-column-text'
        columnElementText.textContent = message[i];
        columnElement.append(columnElementText);
        lineElement.append(columnElement);
    }

    document.getElementById('songs').append(lineElement);

    lineElement.addEventListener('dblclick', () => {
        if (shared.loadingPlaylist) {
            return;
        }
        playbackQueue.empty = false;
        playbackQueue.metadatas = shared.playlist;
        playbackQueue.currentIndex =
            parseInt(lineElement.children[0].textContent) - 1;
        playbackQueue.load();
        playbackQueue.play = true;
        playbackQueue.playOrPause();
    });
})

document.getElementById('playlist').addEventListener('click', () => {
    if (shared.loadingPlaylist) {
        return;
    }
    shared.loadingPlaylist = true;
    document.getElementById('cover').classList.add('hidden');
    document.getElementById('song-list').classList.add('visible');

    // reset
    const songs = document.getElementById('songs');
    songs.innerHTML = '';
    shared.playlist = [];
    metaIndex = 1;

    window.electronAPI
        .loadPlaylist(document.getElementById('playlist').textContent)
        .then(() => {
            shared.loadingPlaylist = false;
        })
})

document.getElementById('title').addEventListener('click', () => {
    document.getElementById('cover').classList.remove('hidden');
    document.getElementById('song-list').classList.remove('visible');
})