#! /bin/sh
#
# This is /sbin/ykluks-keyscript, which gets called when unlocking the disk
# If you update this file rerun:
#    update-initramfs -u
#
YUBIKEY_LUKS_SLOT=2 #Set this in case the value is missing in /etc/ykluks.cfg

. /etc/ykluks.cfg

message()
{
    if [ -x /bin/plymouth ] && plymouth --ping; then
        plymouth message --text="$*"
    else
        echo "$@" >&2
    fi
    return 0
}

for iteration in {1..20}
do
    if [ -z "$YUBIKEY_CHALLENGE" ]; then
        message "[ERROR] Encryption corrupted, system cannot start."
        break
    fi

    # Check if YubiKey has been inserted during prompt
    # message "Checking to see if yubikey has been inserted."
    check_yubikey_present="$(ykinfo -q -"$YUBIKEY_LUKS_SLOT")"
    
    if [ "$check_yubikey_present" != "1" ]; then
        # message "Yubikey not found, retrying: $iteration"
        sleep 1
        continue
    fi
  
    # message "Accessing yubikey..."

    PW=$YUBIKEY_CHALLENGE
    PW=$(printf %s "$PW" | sha256sum | awk '{print $1}')

    R="$(printf %s "$PW" | ykchalresp -"$YUBIKEY_LUKS_SLOT" -i- 2>/dev/null || true)"
    if [ -z "$R" ]; then
        # message "Failed to retrieve the response from the Yubikey."
        continue
    fi
    
    # message "Retrieved the response from the Yubikey."
    printf '%s' "$R"
    exit 0
done

message "[ERROR] Encryption corrupted, system cannot start."

sleep 3600

if [ -z "$cryptkeyscript" ]; then
  if [ -x /bin/plymouth ] && plymouth --ping; then
      cryptkeyscript="plymouth ask-for-password --prompt"
  else
      cryptkeyscript="/lib/cryptsetup/askpass"
  fi
fi

WELCOME_TEXT="[ERROR]"
PW="$($cryptkeyscript "$WELCOME_TEXT")"
printf '%s' "$PW"

exit 0
