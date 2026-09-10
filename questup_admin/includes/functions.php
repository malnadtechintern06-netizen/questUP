<?php
/**
 * QuestUP Admin Common Helper Functions
 */

declare(strict_types=1);

function e(?string $value): string {
    return htmlspecialchars((string)($value ?? ''), ENT_QUOTES, 'UTF-8');
}

function set_flash(string $type, string $message): void {
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    $_SESSION['flash_messages'][] = [
        'type' => $type, // 'success', 'danger', 'warning', 'info'
        'message' => $message,
    ];
}

function get_flash(): array {
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    $messages = $_SESSION['flash_messages'] ?? [];
    unset($_SESSION['flash_messages']);
    return $messages;
}

function render_flash(): string {
    $messages = get_flash();
    if (empty($messages)) {
        return '';
    }

    $html = '<div class="flash-messages-container">';
    foreach ($messages as $msg) {
        $type = e($msg['type']);
        $icon = match ($type) {
            'success' => '<i class="fas fa-check-circle"></i>',
            'danger', 'error' => '<i class="fas fa-exclamation-triangle"></i>',
            'warning' => '<i class="fas fa-exclamation-circle"></i>',
            default => '<i class="fas fa-info-circle"></i>',
        };
        $alertClass = ($type === 'error') ? 'danger' : $type;
        $html .= sprintf(
            '<div class="alert alert-%s alert-dismissible fade show glow-border" role="alert">
                <span class="alert-icon">%s</span>
                <span class="alert-text">%s</span>
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>',
            $alertClass,
            $icon,
            e($msg['message'])
        );
    }
    $html .= '</div>';
    return $html;
}

function time_ago(?string $datetime): string {
    if (empty($datetime)) return 'Never';
    $timestamp = strtotime($datetime);
    if (!$timestamp) return 'Invalid date';

    $diff = time() - $timestamp;
    if ($diff < 0) $diff = 0;

    if ($diff < 60) {
        return 'Just now';
    } elseif ($diff < 3600) {
        $mins = (int)floor($diff / 60);
        return $mins . ' min' . ($mins > 1 ? 's' : '') . ' ago';
    } elseif ($diff < 86400) {
        $hours = (int)floor($diff / 3600);
        return $hours . ' hr' . ($hours > 1 ? 's' : '') . ' ago';
    } elseif ($diff < 2592000) {
        $days = (int)floor($diff / 86400);
        return $days . ' day' . ($days > 1 ? 's' : '') . ' ago';
    } else {
        return date('M j, Y', $timestamp);
    }
}

function format_number(int|float $num): string {
    if ($num >= 1000000) {
        return round($num / 1000000, 1) . 'M';
    } elseif ($num >= 1000) {
        return round($num / 1000, 1) . 'k';
    }
    return number_format($num);
}

function generate_uuid(): string {
    $data = random_bytes(16);
    $data[6] = chr(ord($data[6]) & 0x0f | 0x40); // Version 4
    $data[8] = chr(ord($data[8]) & 0x3f | 0x80); // Variant
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function json_response(array $data, int $statusCode = 200): void {
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function get_difficulty_badge(string $diff): string {
    $diff = strtolower($diff);
    $class = match ($diff) {
        'easy' => 'badge-difficulty-easy',
        'medium' => 'badge-difficulty-medium',
        'hard' => 'badge-difficulty-hard',
        'legendary' => 'badge-difficulty-legendary',
        default => 'badge-difficulty-medium',
    };
    return sprintf('<span class="custom-badge %s"><i class="fas fa-shield-alt me-1"></i>%s</span>', $class, ucfirst($diff));
}

function get_category_badge(string $category): string {
    $cat = strtolower($category);
    $icon = match ($cat) {
        'exploration', 'location' => 'fa-map-marker-alt',
        'fitness', 'movement' => 'fa-running',
        'creativity', 'drawing' => 'fa-paint-brush',
        'intellect', 'writing', 'riddle' => 'fa-brain',
        'social' => 'fa-users',
        'qr', 'scan' => 'fa-qrcode',
        default => 'fa-compass',
    };
    return sprintf('<span class="custom-badge badge-category"><i class="fas %s me-1"></i>%s</span>', $icon, ucfirst($cat));
}

function get_verification_badge(string $vtype): string {
    $icon = match ($vtype) {
        'locationGps' => 'fa-crosshairs text-cyan',
        'photo' => 'fa-camera text-purple',
        'drawing' => 'fa-draw-polygon text-gold',
        'writing' => 'fa-feather-alt text-success',
        'qrCode' => 'fa-qrcode text-info',
        'codePhrase' => 'fa-key text-warning',
        default => 'fa-check-circle text-primary',
    };
    return sprintf('<span class="custom-badge badge-vtype"><i class="fas %s me-1"></i>%s</span>', $icon, e($vtype));
}

function get_status_badge(string|int $status): string {
    if (is_numeric($status)) {
        return ((int)$status === 1)
            ? '<span class="custom-badge badge-status-active"><i class="fas fa-check-circle me-1"></i>Active</span>'
            : '<span class="custom-badge badge-status-inactive"><i class="fas fa-ban me-1"></i>Inactive</span>';
    }

    $st = strtolower((string)$status);
    return match ($st) {
        'verified', 'approved', 'active' => '<span class="custom-badge badge-status-active"><i class="fas fa-check-circle me-1"></i>' . ucfirst($st) . '</span>',
        'pending' => '<span class="custom-badge badge-status-pending"><i class="fas fa-clock me-1"></i>Pending</span>',
        'review' => '<span class="custom-badge badge-status-review"><i class="fas fa-eye me-1"></i>Review</span>',
        'rejected', 'disabled', 'inactive', 'banned' => '<span class="custom-badge badge-status-inactive"><i class="fas fa-times-circle me-1"></i>' . ucfirst($st) . '</span>',
        default => '<span class="custom-badge badge-secondary">' . e($st) . '</span>',
    };
}
