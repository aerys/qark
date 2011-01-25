<?php

class Qark
{
  const MAGIC                   = 0x3121322b;

  const FLAG_NONE               = 0;
  const FLAG_GZIP               = 1;
  const FLAG_DEFLATE            = 2;

  const TYPE_CUSTOM             = 0;
  const TYPE_OBJECT             = 1;
  const TYPE_ARRAY              = 2;
  const TYPE_INT                = 3;
  const TYPE_UINT               = 4;
  const TYPE_FLOAT              = 5;
  const TYPE_STRING             = 6;
  const TYPE_BYTES              = 7;
  const TYPE_BOOLEAN            = 8;
  const TYPE_BITMAP_DATA        = 9;

  private static $ENCODERS      = array('encodeCustomObject',
                                        'encodeObject',
                                        'encodeArray',
                                        'encodeInteger',
                                        'encodeUnsignedInteger',
                                        'encodeFloat',
                                        'encodeString',
                                        'encodeBytes',
                                        'encodeBoolean',
                                        'encodeBitmapData');

  private static $DECODERS      = array('decodeCustomObject',
                                        'decodeObject',
                                        'decodeArray',
                                        'decodeInteger',
                                        'decodeUnsignedInteger',
                                        'decodeFloat',
                                        'decodeString',
                                        'decodeBytes',
                                        'decodeBoolean',
                                        'decodeBitmapData');

  private static function isUnsignedInt($value)
  {
    return ctype_digit((string) $value);
  }

  private static function isAssociativeArray($array)
  {
    return is_array($array)
           && (count($array) == 0
               || 0 !== count(array_diff_key($array, array_keys(array_keys($array)))));
  }

  public static function getType($value)
  {
    if (self::isUnsignedInt($value))
      return self::TYPE_UINT;
    if (is_int($value))
      return self::TYPE_INT;
    if (is_float($value))
      return self::TYPE_FLOAT;
    if (is_string($value) && mb_check_encoding($value, 'UTF-8'))
      return self::TYPE_STRING;
    if (is_string($value))
      return self::BYTES;
    if (self::isAssociativeArray($value))
      return self::TYPE_OBJECT;

    if (function_exists('imagecreatetruecolor'))
    {
      try
      {
        imagesx($source);
        return self::TYPE_BITMAP_DATA;
      }
      catch (Exception $e)
      {
        // NOTHING
      }
    }

    return self::TYPE_OBJECT;
  }

  public static function encode($source)
  {
    $header = self::writeInteger('', self::MAGIC);

    $data = self::encodeRecursive($source, '');
    $size = strlen($data);

    $compressedData = gzcompress($data);
    $compressedSize = strlen($compressedData);

    $deflatedData = gzdeflate($data);
    $deflatedSize = strlen($deflatedData);

    if ($compressedSize < $size && $compressedSize < $deflatedSize)
    {
      $header = self::writeByte($header, self::FLAG_GZIP);
      $data = $compressedData;
    }
    else if ($deflatedSize < $size && $deflatedSize < $compressedSize)
    {
      $header = self::writeByte($header, self::FLAG_DEFLATE);
      $data = $deflatedData;
    }
    else
    {
      $header = self::writeByte($header, self::FLAG_NONE);
    }

    return $header . $data;
  }

  public static function decode($source)
  {
    list($magic, $source) = self::readInteger($source);

    if ($magic !== self::MAGIC)
      return null;

    list($flags, $source) = self::readByte($source);

    if ($flags & self::FLAG_GZIP)
      $source = gzuncompress($source);
    else if ($flags & self::FLAG_DEFLATE)
      $source = gzinflate($source);

    list($value, $source) = self::decodeRecursive($source);

    return $value;
  }

  public static function encodeRecursive($source, $target)
  {
    $type = self::getType($source);
    $target = self::writeByte($target, $type);
    $encoder = self::$ENCODERS[$type];

    return self::$encoder($source, $target);
  }

  public static function decodeRecursive($source)
  {
    list($type, $source) = self::readByte($source);
    $decoder = self::$DECODERS[$type];

    return self::$decoder($source);
  }

  public static function encodeInteger($source, $target)
  {
    return self::writeInteger($target, $source);
  }

  public static function decodeInteger($source)
  {
    return self::readInteger($source);
  }

  public static function encodeUnsignedInteger($source, $target)
  {
    return self::writeUnsignedInteger($target, $source);
  }

  public static function decodeUnsignedInteger($source)
  {
    return self::readUnsignedInteger($source);
  }

  public static function encodeFloat($source, $target)
  {
    return self::writeFloat($target, $source);
  }

  public static function decodeFloat($source)
  {
    return self::readFloat($source);
  }

  public static function encodeString($source, $target)
  {
    return self::writeUTF($target, $source);
  }

  public static function decodeString($source)
  {
    return self::readUTF($source);
  }

  public static function encodeObject($source, $target)
  {
    $target = self::writeShort($target, count($source));

    foreach ($source as $propertyName => $value)
    {
      $target = self::writeUTF($target, utf8_encode($propertyName));
      $target = self::encodeRecursive($value, $target);
    }

    return $target;
  }

  public static function decodeObject($source)
  {
    $object = array();

    list($length, $source) = self::readShort($source);

    while ($length)
    {
      list($propertyName, $source) = self::readUTF($source);
      list($value, $source) = self::decodeRecursive($source);

      $object[utf8_decode($propertyName)] = $value;

      $length--;
    }

    return array($object, $source);
  }

  public static function encodeArray($source, $target)
  {
    $target = self::writeShort($target, count($source));

    foreach ($source as $value)
      $target = self::encodeRecursive($value, $target);

    return $target;
  }

  public static function decodeArray($source)
  {
    $array = array();

    list($length, $source) = self::readShort($source);

    while ($length)
    {
      list($value, $source) = self::decodeRecursive($source);

      $array[] = $value;

      $length--;
    }

    return array($array, $source);
  }

  public static function encodeCustomObject($source, $target)
  {
    return self::encodeObject($source, $target);
  }

  public static function decodeCustomObject($source)
  {
    return self::decodeObject($source);
  }

  public static function encodeBitmapData($source, $target)
  {
    $width = imagesx($source);
    $height = imagesy($source);

    $target = self::writeShort($width);
    $target = self::writeShort($height);

    for ($y = 0; $y < $height; $y++)
      for ($x = 0; $x < $width; $x++)
        $target = self::writeInteger(imagecolorat($source, $x, $y));

    return $target;
  }

  public static function decodeBitmapData($source)
  {
    if (!function_exists('imagecreatetruecolor'))
      throw new Exception('Unable to decode bitmap data: the GD extension is '
                          . 'missing');

    list($width, $source) = self::readShort($source);
    list($height, $source) = self::readShort($source);

    $img = imagecreatetruecolor($width, $height);

    for ($y = 0; $y < $height; $y++)
    {
      for ($x = 0; $x < $width; $x++)
      {
        list($color, $target) = self::readInteger($target);

        imagesetpixel($img, $x, $y, $color);
      }
    }

    return array($img, $source);
  }

  public static function encodeBytes($source, $target)
  {
    $target = self::writeInteger(strlen($source));

    return self::writeBytes($source, $target);
  }

  public static function decodeBytes($source)
  {
    list($length, $source) = self::readInteger($source);

    return self::readBytes($source, $length);
  }

  public static function encodeBoolean($source, $target)
  {
    return self::writeByte($target, $source ? 1 : 0);
  }

  public static function decodeBoolean($source)
  {
    list($value, $source) = self::readByte($source);

    return array($value != 0, $source);
  }

  public static function readByte($source)
  {
    $byte = unpack('C', $source);

    return array((int)$byte[1], substr($source, 1));
  }

  public static function writeByte($source, $byte)
  {
    $source .= pack('C', (int)$byte);

    return $source;
  }

  public static function readBytes($source, $length)
  {
    $bytes = unpack('C' . $length, $source);

    return array($bytes, substr($source, $length));
  }

  public static function writeBytes($source, $bytes)
  {
    for ($i = 0; $i < $length; $i++)
      $source = self::writeByte($source, $bytes[$i]);

    return $source;
  }

  public static function readShort($source)
  {
    $short = unpack('n', $source);

    return array((int)$short[1], substr($source, 2));
  }

  public static function writeShort($source, $short)
  {
    $source .= pack('n', (int)$short);

    return $source;
  }

  public static function readInteger($source)
  {
    $integer = unpack('i', $source);

    return array((int)$interger[1], substr($source, 4));
  }

  public static function writeInteger($source, $integer)
  {
    $source .= pack('i', (int)$integer);

    return $source;
  }

  public static function readUnsignedInteger($source)
  {
    $integer = unpack('I', $source);

    return array((int)$integer[1], substr($source, 4));
  }

  public static function writeUnsignedInteger($source, $integer)
  {
    $source .= pack('I', (int)$integer);

    return $source;
  }

  public static function readFloat($source)
  {
    $float = unpack('f', $source);

    return array((float)$float, substr($source, 4));
  }

  public static function writeFloat($source, $float)
  {
    $source .= pack('f', (float)$float);

    return $source;
  }

  public static function readUTF($source)
  {
    list($length, $source) = self::readShort($source);
    list($bytes, $source) = self::readBytes($source, $length);

    $string = '';
    foreach ($bytes as $byte)
      $string .= chr($byte);

    return array($string, $source);
  }

  public static function writeUTF($source, $string)
  {
    $length = strlen($string);

    $source = self::writeShort($source, $length);

    for ($i = 0; $i < $length; $i++)
      $source = self::writeByte($source, ord($string[$i]));

    return $source;
  }
}

?>