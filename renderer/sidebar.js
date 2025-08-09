import { shared } from "./shared.js";
import { formatTime } from "./shared.js";

import { addSongToList } from "./songList.js";

let metaIndex = 1;
window.electronAPI.receiveSongMetadata((metadata) => {
    if (!metadata) {
        return;
    }
    shared.playlist.push(metadata);
    let message = [
        metaIndex++, metadata.title, metadata.artist, metadata.album,
        formatTime(metadata.duration)
    ];
    addSongToList(message, metadata.coverDataUrl);
})

window.electronAPI.resetPlaylist(() => {
    // reset
    const songs = document.getElementById('song-list').children;
    let len = songs.length;
    for (let i = len - 1; i >= 1; i--) {
        songs[i].remove();
    }
    shared.playlist = [];
    metaIndex = 1;
})

document.getElementById('playlist').addEventListener('click', () => {
    if (shared.loadingPlaylist) {
        return;
    }
    shared.loadingPlaylist = true;
    document.getElementById('cover').classList.add('hidden');
    document.getElementById('song-list').classList.add('display');

    window.electronAPI
        .loadPlaylist(document.getElementById('playlist').textContent)
        .then(() => {
            shared.loadingPlaylist = false;
        })
})

document.getElementById('title').addEventListener('click', () => {
    document.getElementById('cover').classList.remove('hidden');
    document.getElementById('song-list').classList.remove('display');
})