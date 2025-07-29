let clickPlaybackQueueBtn = false;
let playbackQueueDisplay = false;
document.querySelectorAll('.playback-queue-btn')
    .forEach(element => element.addEventListener('click', () => {
        clickPlaybackQueueBtn = true;
        playbackQueueDisplay = !playbackQueueDisplay;
        if (playbackQueueDisplay)
            document.getElementById('playback-queue').classList.add('display');
        else
            document.getElementById('playback-queue').classList.remove('display');
    }));

document.addEventListener('click', (e) => {
    if (clickPlaybackQueueBtn) {
        clickPlaybackQueueBtn = false;
        return;
    }
    if (playbackQueueDisplay) {
        playbackQueueDisplay = false;
        document.getElementById('playback-queue').classList.remove('display');
    }
})
