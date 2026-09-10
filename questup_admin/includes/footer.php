<?php
/**
 * QuestUP Admin - Footer Include
 */

declare(strict_types=1);
?>
    </main>

    <!-- Footer Copyright -->
    <footer class="py-3 px-4 text-center text-muted border-top" style="background: var(--bg-surface); border-color: var(--border-subtle) !important; font-size: 0.8rem;">
        <div class="d-flex flex-column flex-sm-row justify-content-between align-items-center gap-2">
            <div>&copy; <?= date('Y') ?> <strong>QuestUP</strong> - Real World Gamified Adventure Admin Panel.</div>
            <div>Connected Database: <span class="text-cyan fw-bold">questup_db</span> | PHP <?= PHP_VERSION ?></div>
        </div>
    </footer>
</div><!-- /.admin-main -->
</div><!-- /.admin-wrapper -->

<!-- Toast Notification Container -->
<div class="toast-container position-fixed bottom-0 end-0 p-3" id="toastContainer" style="z-index: 1100;"></div>

<!-- Bootstrap 5 JS Bundle -->
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

<!-- Leaflet JS -->
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

<!-- Custom Admin JS -->
<script src="<?= $baseUrl ?>assets/js/admin.js?v=1.0.0"></script>

<?php if (isset($extraScripts)): ?>
    <?= $extraScripts ?>
<?php endif; ?>

</body>
</html>
