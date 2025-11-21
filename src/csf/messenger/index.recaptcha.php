<!doctype html>
<html lang="en">
<head>
	<title>Unauthorized Access</title>
	<meta charset="UTF-8">
	<script src="https://www.google.com/recaptcha/api.js" async defer></script>
	<link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css'>
	<link rel="icon" href="data:;base64,iVBORw0KGgo=">
</head>
<body>
    <?php require('../recaptcha.php'); ?>
	<?php
		$lang = "en";
		if (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
			$lang = substr($_SERVER['HTTP_ACCEPT_LANGUAGE'], 0, 2);
		}
		
		// Sanitize language input to prevent directory traversal attempts
		$lang = preg_replace('/[^a-z]/', '', $lang);
		if(empty($lang)) { $lang = "en"; }

		if(file_exists('../'.$lang.'.php')) {
			require('../'.$lang.'.php');
		}else{
			require('../en.php');
		}
	?>

<div class="container-fluid">
	<img src="data:image/png;base64,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" />
	<div class="alert alert-warning"><h2><?php echo $lang["warning"]; ?></h2></div>
	<p><?php echo $lang["contact"]; ?></p>
	<p><?php echo $lang["blocked ip"]; ?> <b><?php echo $_SERVER['REMOTE_ADDR'] ?></b></p>
	<p><?php echo $lang["hostname"]; ?> <b><?php echo php_uname('n'); ?></b></p>

	<br />
	<p><?php echo $lang["recaptcha title"]; ?></p>

	<form action="" method="POST">
		<div class="row">
			<div class="col-md-4 col-md-offset-4">
				<div class="panel panel-default">
					<div class="panel-body">
						<div class="g-recaptcha" data-sitekey="<?php echo $sitekey; ?>"></div>
					</div>
					<div class="panel-footer text-center">
						<button class='btn btn-primary' type="submit" name="submit"><?php echo $lang["unblock submit"]; ?></button>
					</div>
				</div>
			</div>
		</div>
	</form>

	<br />
	<?php
		if (!empty($_POST)) {
			$alert = '';
			$message = '';
			$pieces = explode(".", php_uname('n'));
			$date = @date('M j H:i:s'). " " . $pieces[0] . " ";
			if (isset($_POST['g-recaptcha-response']) && !empty($_POST['g-recaptcha-response'])) {
				$data = array('secret' => $secret,'response' => $_POST['g-recaptcha-response']);
				$verify = curl_init();
				curl_setopt($verify, CURLOPT_URL, "https://www.google.com/recaptcha/api/siteverify");
				curl_setopt($verify, CURLOPT_POST, true);
				curl_setopt($verify, CURLOPT_POSTFIELDS, http_build_query($data));
				curl_setopt($verify, CURLOPT_SSL_VERIFYPEER, false);
				curl_setopt($verify, CURLOPT_RETURNTRANSFER, true);
				$verifyResponse = curl_exec($verify);
				$responseData = json_decode($verifyResponse);
				
				// RHEL 8 Fix: Ensure $responseData is valid before accessing properties
				if($responseData && $responseData->success) {
					if ($responseData->hostname == $_SERVER['SERVER_NAME']) {
						$alert = 'success';
						// Security Fix: Escape the Request URI to prevent Reflected XSS
						$clean_uri = htmlspecialchars($_SERVER['REQUEST_URI'], ENT_QUOTES, 'UTF-8');
						$message = $lang["recaptcha success"] . "<br /><a href='" . $clean_uri . "'>" . $clean_uri . "</a>";
						file_put_contents($unblockfile, $_SERVER['REMOTE_ADDR'].";".$_SERVER['SERVER_NAME'].";".$_SERVER['SERVER_ADDR']."\n", FILE_APPEND | LOCK_EX);
						file_put_contents($logfile,$date . "*Success*, ReCaptcha (" . $_SERVER['REMOTE_ADDR'].": [".$_SERVER['SERVER_NAME']." (".$_SERVER['SERVER_ADDR'].")] requested unblock\n", FILE_APPEND | LOCK_EX);
					} else {
						$alert = "danger";
						$message = $lang["recaptcha hostfail"] . ' ['.$responseData->hostname.' != '.$_SERVER['SERVER_NAME'].']';
						file_put_contents($logfile,$date . "*Failed*, ReCaptcha (" . $_SERVER['REMOTE_ADDR'].": [".$_SERVER['SERVER_NAME']." (".$_SERVER['SERVER_ADDR'].")] does not appear to be hosted on this server\n", FILE_APPEND | LOCK_EX);
					}
				} else {
					$alert = "danger";
					$message = $lang["recaptcha failure"];
					file_put_contents($logfile,$date . "*Error*, ReCaptcha (" . $_SERVER['REMOTE_ADDR'].": " . json_encode($responseData) . "\n", FILE_APPEND | LOCK_EX);
				}
			} else {
				$alert = "danger";
				$message = $lang["recaptcha error"];
			}
			echo '<div class="alert alert-' . $alert . '"><h4>' . $message . '</h4></div>';
		}
	?>

	<div class="alert alert-info"><?php echo $lang["recaptcha note"]; ?></div>
</div>
</body>
</html>