<?php
require("../init.php");



?>
<!DOCTYPE html>
<html lang="en">
  <head>
    <?php include($_SERVER["DOCUMENT_ROOT"]."/includes/meta.php");?>
    <?php include($_SERVER["DOCUMENT_ROOT"]."/includes/title.php");?>
    <?php include($_SERVER["DOCUMENT_ROOT"]."/includes/css.php");?>

  </head>
  <body>
    <?php include($_SERVER["DOCUMENT_ROOT"]."/includes/top-menu.php");?>

    <div class="container">

      <h1>Telecube Cloud PBX!</h1>

      <p>&nbsp;</p>
      
      <p><a href="git-update.php">Run Code Update</a></p>

      <p><a href="db-update.php">Run Database Update</a></p>

      <p><a href="system-update.php">Run System Update</a></p>

    </div>

    <?php include($_SERVER["DOCUMENT_ROOT"]."/includes/js.php");?>
  
  </body>
</html>