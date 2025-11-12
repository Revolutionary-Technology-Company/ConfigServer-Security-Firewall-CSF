<?php
// --- Configuration ---
// Create a secure directory OUTSIDE your public_html
// e.g., /home/username/protected_versions/
// In that folder, place your version files: csf.txt, cxs.txt, etc.
$version_files_path = '/home/revolutionarytec/configserver.shop/repos/safe/';
// ---------------------

define('_JEXEC', 1);
define('JPATH_BASE', realpath(dirname(__FILE__) . '/..')); // Adjust path to Joomla root
require_once JPATH_BASE . '/includes/defines.php';
require_once JPATH_BASE . '/includes/framework.php';

try {
    $app = JFactory::getApplication('site');
    $db  = JFactory::getDbo();

    // 1. Get and sanitize inputs
    $license_key = $app->input->get('license_key', '', 'string');
    $product     = $app->input->get('product', '', 'string');

    // Only allow simple product names (csf, cxs, etc.)
    if (empty($license_key) || !preg_match('/^[a-fA-F0-9]{17}$/', $license_key)) {
        http_response_code(403);
        die('ERROR: Invalid or missing license key.');
    }
    if (empty($product) || !preg_match('/^[a-z]{3,5}$/', $product)) {
        http_response_code(400);
        die('ERROR: Invalid product specified.');
    }

    // 2. Validate the license key (case-insensitive)
    $query = $db->getQuery(true)
        ->select($db->quoteName('serial_id'))
        ->from($db->quoteName('#__hikaserial_serial'))
        ->where('UPPER(' . $db->quoteName('serial_data') . ') = ' . $db->quote(strtoupper($license_key)))
        ->where($db->quoteName('serial_published') . ' = 1');

    $db->setQuery($query);
    $result = $db->loadResult();

    if (!$result) {
        http_response_code(403);
        die('ERROR: License key not found or inactive.');
    }

    // 3. License is valid! Serve the correct version file.
    //    We use a switch to be extra safe about what file is served.
    $file_to_serve = '';
    switch ($product) {
        case 'csf':
            $file_to_serve = 'csf.txt';
            break;
        case 'cxs':
            $file_to_serve = 'cxs.txt';
            break;
        case 'cmm':
            $file_to_serve = 'cmm.txt';
            break;
        // Add all your other product codes here...
        default:
            http_response_code(404);
            die('ERROR: Unknown product.');
    }

    $full_path = $version_files_path . $file_to_serve;

    if (file_exists($full_path)) {
        header('Content-Type: text/plain');
        header('Content-Length: ' . filesize($full_path));
        readfile($full_path);
        exit;
    } else {
        http_response_code(500);
        die('ERROR: Version file not found on server.');
    }

} catch (Exception $e) {
    http_response_code(500);
    die('ERROR: Server error.');
}