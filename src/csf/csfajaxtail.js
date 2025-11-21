/*
    @app                ConfigServer Firewall & Security (CSF)
                        Login Failure Daemon (LFD)
    @website            https://configserver.shop
    @docs               https://docs.configserver.shop
    @download           https://download.configserver.shop
    @repo               https://github.com/orgs/Revolutionary-Technology-Company/
    @copyright          Copyright (C) 2025-2026 Revolutionary Technology https://revolutionarytechnology.net
                        Copyright (C) 2006-2025 Jonathan Michaelson
                        Copyright (C) 2006-2025 Way to the Web Ltd.
    @license            GPLv3
    @updated            10.15.2025
    
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or (at
    your option) any later version.
    
    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program; if not, see <https://www.gnu.org/licenses>.
*/

/*
	Declarations

	@note				Existing vars are replaced dynamically by Perl injection via DisplayUI.pm;
						must remain var for global exposure and mutation safety.
*/

var csfScript = '';
var csfDuration = (typeof csfDuration !== 'undefined') ? csfDuration : 6;
var csfStartPaused = (typeof csfStartPaused !== 'undefined') ? csfStartPaused : 0;

var csfFromBot = 120;
var csfFromRight = 10;

let csfCounter;
let csfCount = 1;
let csfPause = csfStartPaused;
let csfTimerSet = 0;
let csfHeight = 0;
let csfWidth = 0;

// Modern XMLHttpRequest setup
const csfAjaxHttp = new XMLHttpRequest();

/*
    Initial state of pause button
*/
document.addEventListener("DOMContentLoaded", function() {
    const pauseBtn = document.getElementById('csfPauseId');
    if (pauseBtn) {
        pauseBtn.textContent = csfPause ? 'Continue' : 'Pause';
    }
});

/*
    Sends an asynchronous GET request to the specified URL
*/
function csfSendReq(url) {
    const now = new Date();
    const refreshIcon = document.getElementById('csfRefreshing');
    
    if(refreshIcon) refreshIcon.style.display = 'inline';

    csfAjaxHttp.open('GET', url + '&nocache=' + now.getTime(), true);
    
    csfAjaxHttp.onreadystatechange = csfHandleResp;
    
    csfAjaxHttp.onerror = function() {
        console.error("CSF AJAX Error: Request failed.");
        if(refreshIcon) refreshIcon.style.display = 'none';
    };

    csfAjaxHttp.send();
}

/*
    Handles and processes the ajax response from the server
*/
function csfHandleResp() {
    if (csfAjaxHttp.readyState === 4) {
        const refreshIcon = document.getElementById('csfRefreshing');
        
        if (csfAjaxHttp.status === 200) {
            if (csfAjaxHttp.responseText) {
                const csfObj = document.getElementById('csfAjax');
                if (csfObj) {
                    csfObj.innerHTML = csfAjaxHttp.responseText;
                    
                    // Enforce styles for Webmin/InterWorx compatibility
                    csfObj.style.setProperty('min-height', '500px');
                    csfObj.style.setProperty('resize', 'vertical', 'important');
                    csfObj.style.setProperty('overflow', 'auto', 'important');

                    // Auto-scroll to bottom
                    csfObj.scrollTop = csfObj.scrollHeight;
                }

                if (refreshIcon) refreshIcon.style.display = 'none';

                if (csfTimerSet) {
                    clearInterval(csfCounter); // Clear existing to prevent stacking
                    csfCounter = setInterval(csfTimerInitialize, 1000);
                }
            }
        } else {
            console.warn("CSF AJAX Warning: Server returned status " + csfAjaxHttp.status);
            if (refreshIcon) refreshIcon.style.display = 'none';
        }
    }
}

/*
    Handles log grep requests using user input and selected options
*/
function csfGrep() {
    csfTimerSet = 0;
    if (csfCounter) clearInterval(csfCounter);

    const csfLogObj = document.getElementById('csfLogNum');
    let csfLogNum = csfLogObj ? '&lognum=' + csfLogObj.value : '';

    if (document.getElementById('CSFgrep_i').checked) csfLogNum += '&grepi=1';
    if (document.getElementById('CSFgrep_E').checked) csfLogNum += '&grepE=1';
    if (document.getElementById('CSFgrep_Z').checked) csfLogNum += '&grepZ=1';

    const grepVal = encodeURIComponent(document.getElementById('csfGrep').value);
    const csfUrl = csfScript + '&grep=' + grepVal + csfLogNum;
    
    csfSendReq(csfUrl);
}

/*
    Timer › Initialize
    Automatically refreshes on-screen logs at regular intervals
*/
function csfTimerInitialize() {
    csfTimerSet = 1;
    const timerEl = document.getElementById('csfTimer');
    
    if (!timerEl) return;

    /*
        If paused, just update the display and skip decrement
    */
    if (csfPause) {
        timerEl.textContent = 'Paused';
        return;
    }

    csfCount--;
    timerEl.textContent = csfCount;

    if (csfCount <= 0) {
        const logObj = document.getElementById('csfLogNum');
        const linesObj = document.getElementById('csfLines');
        
        if(linesObj) {
            const linesVal = linesObj.value;
            const logNum = logObj ? `&lognum=${ logObj.value }` : '';
            csfSendReq(`${ csfScript }&lines=${ linesVal }${ logNum }`);
        }
        csfCount = csfDuration;
    }
}

/*
    Timer › Pause
    Toggles the automatic refresh pause state and updates button text
*/
function csfTimerPause() {
    csfPause = !csfPause; // Toggle boolean

    const pauseBtn = document.getElementById('csfPauseId');
    if (pauseBtn) {
        pauseBtn.textContent = csfPause ? 'Continue' : 'Pause';
        pauseBtn.className = csfPause ? 'btn btn-success' : 'btn btn-warning'; // Visual feedback if bootstrap exists
    }
    
    // Immediate UI update
    const timerEl = document.getElementById('csfTimer');
    if (timerEl && csfPause) timerEl.textContent = 'Paused';
}

/*
    Timer › Refresh
    Forces an immediate refresh without waiting for timer to expire
*/
function csfTimerRefresh() {
    // Temporarily unpause to force a tick
    const wasPaused = csfPause;
    csfPause = false;
    
    // Reset count to trigger immediate fetch in next tick or manual call
    csfCount = 0; 
    csfTimerInitialize(); // Run immediately
    
    // Restore state and reset counter for next cycle
    csfPause = wasPaused;
    csfCount = csfDuration;
    
    const timerEl = document.getElementById('csfTimer');
    if (timerEl) timerEl.textContent = csfCount;
}

/*
    Gets and stores the current browser window width and height
*/
function windowSize() {
    csfHeight = window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;
    csfWidth = window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth;
}