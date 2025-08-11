window.electronAPI.maximize(() => {
    document.querySelectorAll('.maximize').forEach(element => {
        element.style.backgroundImage = 'url(\'pictures/unmaximize.png\')';
    });
})

window.electronAPI.unmaximize(() => {
    document.querySelectorAll('.maximize').forEach(element => {
        element.style.backgroundImage = 'url(\'pictures/maximize.png\')';
    });
})
