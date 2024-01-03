#!/bin/bash
read -p "请输入你测试的网段地址[1/2]:" num
network1=192.168.168
network2=192.168.169
if [ $num -eq 1 ]; then
    for i in {2..254}
    do
        {
          ping $network1.$i -c1 -W1&> /dev/null
      if [ `echo $?` -eq 0 ];then
          echo "$network1.$i is online" >> /root/ip.txt
          else
          echo "$network1.$i is down" >> /root/ip.txt

        fi
        } &

      done
  else
    for i in {2..254}
    do
      {
        ping $network2.$i -c1 -W1&> /dev/null
      if [ `echo $?` -eq 0 ];then
          echo "$network2.$i is online" >> /root/ip.txt
          else
          echo "$network2.$i is down" >> /root/ip.txt

        fi
        } &

      done
fi