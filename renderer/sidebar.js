import { changePlayQueueDisplayStatus } from "./playQueueControls.js";
import { shared, songList } from "./shared.js";
import { formatTime } from "./shared.js";

import { fillSongMetadata, createSongListElements } from "./songList.js";

window.electronAPI.receiveSongMetadatas((metadatas) => {
    metadatas.forEach(metadata => {
        let message = [
            metadata.index, metadata.title, metadata.artist, metadata.album,
            formatTime(metadata.duration)
        ];
        fillSongMetadata(message, metadata.coverDataUrl, metadata.filePath);
    });
})

window.electronAPI.resetPlaylist((size) => {

    if (document.getElementById('search').value != "") {
        // clear search
        document.getElementById('search').value = "";
        document.getElementById('search').dispatchEvent(new Event('input'));
    }
    createSongListElements(size);
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
    if (shared.playQueueDisplay) {
        changePlayQueueDisplayStatus();
    }
}

export function displayCover() {
    // clear search
    document.getElementById('search').value = "";
    document.getElementById('search').dispatchEvent(new Event('input'));
    document.getElementById('cover').style.display = 'block';
    document.getElementById('song-list').style.display = 'none';
    if (shared.playQueueDisplay) {
        changePlayQueueDisplayStatus();
    }
}