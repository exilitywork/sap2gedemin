<?php

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

require './src/Exception.php';
require './src/PHPMailer.php';
require './src/SMTP.php';

$cfg = parse_ini_file('block_card.ini');

$mail = new PHPMailer(true);

if (!empty($_REQUEST['bd'])) {
    $cfg['db_name'] = $_REQUEST['bd'];
}

if (!empty($_REQUEST['card_number'])) {
    system("./block_card.sh ".$_REQUEST['card_number']." ".$cfg['db_user']." ".$cfg['db_password']." ".$cfg['db_server']." ".addslashes($cfg['db_path']).$cfg['db_name'], $exit_code);

    // формирование сообщения для лога
    $cfg['db_path'] = stripcslashes($cfg['db_path']);
    switch ($exit_code) {
	case 0:
	    $message = "[".date("Y-m-d H:i:s")."] SUCCESS: Карта ".$_REQUEST['card_number']." заблокирована | Отчет по операциям выгружен в SAP\n";
	    break;
	case 101:
	    $message = "[".date("Y-m-d H:i:s")."] ERROR: Нет соединения с сервером БД ".$cfg['db_server']."\n";
	    break;
	case 102:
	    $message = "[".date("Y-m-d H:i:s")."] ERROR: На сервере ".$cfg['db_server']." не найдена БД ".$cfg['db_path'].$cfg['db_name']."\n";
	    break;
	case 103:
	    $message = "[".date("Y-m-d H:i:s")."] ERROR: Ошибка SQL-запроса при блокировке карты\n";
	    break;
	case 104:
	    $message = "[".date("Y-m-d H:i:s")."] NOTIFICATION: Карта ".$_REQUEST['card_number']." в БД ".$cfg['db_path'].$cfg['db_name']." не найдена\n";
	    break;
	case 105:
	    $message = "[".date("Y-m-d H:i:s")."] ERROR: Ошибка SQL-запроса при поиске табельного номера для карты ".$_REQUEST['card_number']."\n";
	    break;
	case 106:
	    $message = "[".date("Y-m-d H:i:s")."] ERROR: Ошибка SQL-запроса при выгрузке отчета по карте ".$_REQUEST['card_number']."\n";
	    break;
	case 107:
	    $message = "[".date("Y-m-d H:i:s")."] NOTIFICATION: По карте ".$_REQUEST['card_number']." в БД ".$cfg['db_path'].$cfg['db_name']." нет операций на дату ".date("Y-m-d")."\n";
	    break;
	default:
	    $message = "[".date("Y-m-d H:i:s")."] ERROR: Ошибка в работе скрипта!\n";
    }

    // запись в лог сообщения
    $logfile=$cfg['log_dir'].($cfg['log_with_date']?date($cfg['log_date_format']):"").$cfg['log_file'];
    if (!file_exists($logfile)) {
	$newfile = fopen($logfile, 'w+');
	fclose($newfile); 
    }
    error_log($message, 3, $logfile);

    // отправка сообщения по почте
    try {
	// Настройка сервера
	$mail->SMTPDebug  = $cfg['SMTPDebug'];
	$mail->isSMTP();
	$mail->Host       = $cfg['mail_host'];
	$mail->SMTPAuth   = $cfg['SMTPAuth'];
	$mail->Username   = $cfg['mail_username'];
	$mail->Password   = $cfg['mail_password'];
	$mail->SMTPSecure = $cfg['SMTPSecure'];
	$mail->Port       = $cfg['mail_port'];

	// Адреса отправителя и получателей
	$mail->setFrom($cfg['from']);
	$mail->addAddress($cfg['to']);

	// Вложения
	//$mail->addAttachment('/var/tmp/file.tar.gz');
	//$mail->addAttachment('/tmp/image.jpg', 'new.jpg');

	// Тема и текст
	$sub=(($exit_code == 0) || ($exit_code == 107)) ? "Карта сотрудника ".$_REQUEST['card_number']." заблокирована" : "ВНИМАНИЕ! Проблема при блокировке карты сотрудника ".$_REQUEST['card_number'];
	$mail->CharSet = 'utf-8';
	$mail->isHTML(true);
	$mail->Subject = $sub;
	$mail->Body    = $message;
	$mail->AltBody = $message;

	$mail->send();
    } catch (Exception $e) {
	error_log("[".date("Y-m-d H:i:s")."] ERROR: Сообщение не отправлено. Mailer Error: {$mail->ErrorInfo} \n", 3, $logfile);
    }
};
?>