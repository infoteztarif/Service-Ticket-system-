/* Teztarif SaaS in-page notification count refresh (no push when page closed). */
(function () {
    'use strict';

    function init() {
        var root = document.getElementById('TeztarifAlertsRoot');
        if (!root || !root.dataset.pollUrl || root.dataset.pollingStarted) {
            return;
        }
        root.dataset.pollingStarted = '1';
        var countNode = document.getElementById('TeztarifAlertCount');
        var notice = document.getElementById('TeztarifAlertsRefreshNotice');
        var count = parseInt(root.dataset.initialCount || '0', 10);
        var pending = false;

        function refreshCount() {
            if (pending || document.hidden) {
                return;
            }
            pending = true;
            fetch(root.dataset.pollUrl, {
                method: 'GET',
                credentials: 'same-origin',
                cache: 'no-store',
                headers: { 'Accept': 'application/json' }
            }).then(function (response) {
                if (!response.ok) {
                    throw new Error('Alert refresh unavailable');
                }
                return response.json();
            }).then(function (data) {
                if (!data || !Number.isSafeInteger(data.Count) || data.Count < 0) {
                    return;
                }
                if (data.Count !== count) {
                    count = data.Count;
                    if (countNode) {
                        countNode.textContent = String(count);
                    }
                    if (notice) {
                        notice.textContent = 'Alerts changed. Refresh this page to see the latest list.';
                        notice.hidden = false;
                    }
                }
            }).catch(function () {
                if (notice) {
                    notice.textContent = 'Alert refresh unavailable. Use Refresh alerts to retry.';
                    notice.hidden = false;
                }
            }).finally(function () {
                pending = false;
            });
        }

        window.setInterval(refreshCount, 120000);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init, { once: true });
    }
    else {
        init();
    }
}());
