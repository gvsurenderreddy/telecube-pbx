<?php
require_once(__DIR__."/../classes/_autoloader.php");
use Telecube\AGI_AsteriskManager;
use Telecube\Config;
use Telecube\Db;

$Config = new Config;
$Db = new Db;

try{
    $dbPDO = new PDO('mysql:dbname='.$Config->get("db_name").';host='.$Config->get("db_host").';port='.$Config->get("db_port"), $Config->get("db_user"), $Config->get("db_pass"));
} catch(PDOException $ex){
    exit( 'Connection failed: ' . $ex->getMessage() );
}
$dbPDO->setAttribute( PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION );

$password = @file_get_contents("/opt/ami_pass");
$password = trim($password);

$manager = new AGI_AsteriskManager();

$result = $manager->connect("127.0.0.1:5038", "telecube", $password);
if($result === TRUE) {
    echo "connected\n";

    $manager->add_event_handler("*", "event_recorder");

    while(true){
        $manager->wait_response(true);
    }

} else {
    echo "Connection failed.\n";
    exit;
}

function event_recorder($ecode,$data,$server,$port) {
    global $Db, $dbPDO;

    if($ecode == "peerstatus"){
        $ext = str_replace("SIP/", "", $data['Peer']);
        $q = "update sip_devices set register_status = ? where name = ?;";
        $Db->pdo_query($q, array($data['PeerStatus'], $ext), $dbPDO);

        // insert a log entry
        $q = "insert into ami_event_logs (datetime, event_type, peername, event_data) values (?,?,?,?);";
        $Db->pdo_query($q, array(date("Y-m-d H:i:s"), $ecode, $ext, json_encode($data)), $dbPDO);
    }

    if($ecode == "registry"){
        $trunkname = $data['Domain'];
        $q = "update trunks set register_status = ? where name = ?;";
        $Db->pdo_query($q, array($data['Status'], $trunkname), $dbPDO);

        // insert a log entry
        $q = "insert into ami_event_logs (datetime, event_type, peername, event_data) values (?,?,?,?);";
        $Db->pdo_query($q, array(date("Y-m-d H:i:s"), $ecode, $trunkname, json_encode($data)), $dbPDO);
    }

}

?>