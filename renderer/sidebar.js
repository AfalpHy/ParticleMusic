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

    if (document.getElementById('search').value != "") {
        // clear search
        document.getElementById('search').value = "";
        document.getElementById('search').dispatchEvent(new Event('input'));
    }
})

window.electronAPI.setLoadingPlaylist(() => {
    shared.loadingPlaylist = true;
})

window.electronAPI.unsetLoadingPlaylist(() => {
    shared.loadingPlaylist = false;
})

export function displaySongList() {
    // do nothing when search text is not empty
    if (document.getElementById('search').value == "") {
        document.getElementById('cover').style.display = 'none';
        document.getElementById('song-list').style.display = 'block';
    }
}

export function displayCover() {
    // clear search
    document.getElementById('search').value = "";
    document.getElementById('search').dispatchEvent(new Event('input'));
    document.getElementById('cover').style.display = 'block';
    document.getElementById('song-list').style.display = 'none';
}