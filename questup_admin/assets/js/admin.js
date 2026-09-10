/**
 * QuestUP Web Admin Panel - JavaScript Interactions & Utilities
 */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Sidebar Toggle (Mobile & Desktop)
    const sidebar = document.getElementById('adminSidebar');
    const toggleBtn = document.getElementById('sidebarToggleBtn');
    const closeBtn = document.getElementById('sidebarCloseBtn');

    // Restore desktop collapsed preference
    if (window.innerWidth > 992 && localStorage.getItem('questup_sidebar_collapsed') === '1') {
        document.body.classList.add('sidebar-collapsed');
    }

    if (toggleBtn) {
        toggleBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            if (window.innerWidth <= 992) {
                if (sidebar) sidebar.classList.toggle('show');
            } else {
                document.body.classList.toggle('sidebar-collapsed');
                const isCollapsed = document.body.classList.contains('sidebar-collapsed');
                localStorage.setItem('questup_sidebar_collapsed', isCollapsed ? '1' : '0');
                
                // Trigger resize for charts/maps
                window.dispatchEvent(new Event('resize'));
            }
        });
    }

    if (closeBtn && sidebar) {
        closeBtn.addEventListener('click', () => {
            sidebar.classList.remove('show');
        });
    }

    // Close sidebar when clicking outside on mobile
    document.addEventListener('click', (e) => {
        if (sidebar && sidebar.classList.contains('show') && window.innerWidth <= 992) {
            if (!sidebar.contains(e.target) && (!toggleBtn || !toggleBtn.contains(e.target))) {
                sidebar.classList.remove('show');
            }
        }
    });

    // 2. Auto-dismiss alerts after 5 seconds
    const alerts = document.querySelectorAll('.alert-dismissible');
    alerts.forEach(alert => {
        setTimeout(() => {
            try {
                const bsAlert = new bootstrap.Alert(alert);
                bsAlert.close();
            } catch (_) {
                alert.remove();
            }
        }, 5000);
    });
});

// Toast notification helper
function showToast(type, message) {
    const container = document.getElementById('toastContainer');
    if (!container) return;

    const toastEl = document.createElement('div');
    toastEl.className = `toast align-items-center text-white bg-${type === 'error' ? 'danger' : type} border-0 show`;
    toastEl.setAttribute('role', 'alert');
    toastEl.setAttribute('aria-live', 'assertive');
    toastEl.setAttribute('aria-atomic', 'true');

    toastEl.innerHTML = `
        <div class="d-flex">
            <div class="toast-body">
                <i class="fas ${type === 'success' ? 'fa-check-circle' : 'fa-exclamation-triangle'} me-2"></i>
                ${message}
            </div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
        </div>
    `;

    container.appendChild(toastEl);
    setTimeout(() => {
        toastEl.remove();
    }, 4500);
}

// Password toggle helper
function togglePasswordVisibility(inputId, iconId) {
    const input = document.getElementById(inputId);
    const icon = document.getElementById(iconId);
    if (!input) return;

    if (input.type === 'password') {
        input.type = 'text';
        if (icon) {
            icon.classList.remove('fa-eye');
            icon.classList.add('fa-eye-slash');
        }
    } else {
        input.type = 'password';
        if (icon) {
            icon.classList.remove('fa-eye-slash');
            icon.classList.add('fa-eye');
        }
    }
}

// Leaflet Map Picker Helper
function initQuestMapPicker(lat, lng, radius, latInputId, lngInputId, radiusInputId, mapContainerId = 'map-picker') {
    const mapEl = document.getElementById(mapContainerId);
    if (!mapEl || typeof L === 'undefined') return null;

    const initialLat = parseFloat(lat) || 12.9716;
    const initialLng = parseFloat(lng) || 77.5946;
    const initialRadius = parseFloat(radius) || 150;

    const map = L.map(mapContainerId).setView([initialLat, initialLng], 14);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://carto.com/">CARTO</a>',
        maxZoom: 19
    }).addTo(map);

    // Custom Cyan Quest Icon
    const questIcon = L.divIcon({
        className: 'custom-map-pin',
        html: '<div style="background: #00e5ff; width: 22px; height: 22px; border-radius: 50%; border: 3px solid #0a0e17; box-shadow: 0 0 14px #00e5ff;"></div>',
        iconSize: [22, 22],
        iconAnchor: [11, 11]
    });

    let marker = L.marker([initialLat, initialLng], {
        icon: questIcon,
        draggable: true
    }).addTo(map);

    let circle = L.circle([initialLat, initialLng], {
        radius: initialRadius,
        color: '#00e5ff',
        fillColor: '#00e5ff',
        fillOpacity: 0.15,
        weight: 2
    }).addTo(map);

    function updateInputs(cLat, cLng) {
        const latInput = document.getElementById(latInputId);
        const lngInput = document.getElementById(lngInputId);
        if (latInput) latInput.value = cLat.toFixed(6);
        if (lngInput) lngInput.value = cLng.toFixed(6);
    }

    marker.on('drag', function (e) {
        const pos = e.target.getLatLng();
        circle.setLatLng(pos);
        updateInputs(pos.lat, pos.lng);
    });

    map.on('click', function (e) {
        marker.setLatLng(e.latlng);
        circle.setLatLng(e.latlng);
        updateInputs(e.latlng.lat, e.latlng.lng);
    });

    const radiusInput = document.getElementById(radiusInputId);
    if (radiusInput) {
        radiusInput.addEventListener('input', function () {
            const rad = parseFloat(this.value) || 50;
            circle.setRadius(rad);
        });
    }

    return map;
}
