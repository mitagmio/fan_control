#!/bin/bash
#######################
#Script created by 19alexrus71
#For donate - LTC: LaeSwaV5mnXJb6DgccCdHiZNKUCvbfDMFT
#############################################################

#Стартовые обороты кулеров
start_speed=60

#Температура при достижении которой обороты начинают плавно повышаться
high_level=60

#Температура при которой обороты начинают плавно понижаться
low_level=58

#Температура при которой обороты сразу повышаются до very_high_fan
very_high_level=62

#Скорость кулера при достижении very_high_level
very_high_fan=70

#Скорость кулера ниже которой обороты уже не регулируются и переключаются в авторежим
min_fan=35

#Максимальная скорость кулера
max_fan=100

#Пауза между циклами проверки в секундах
PAUSE=10

#Минимальный порог загрузки карт. Если меньше - считается, что майнинг не работает
min_using=50

#Количество циклов с ошибкой (или низкой загрузкой карт), при достижении которого происходит reboot
error_level=15

#Включение/выключение watchdog. Отключить: watch_dog=0. Мониторинг будет происходить, но перезагрузка отключена
watch_dog=1



#########################################################################
export DISPLAY=:0

busy=1
while [ $busy -ne 0 ]
do
	busy=$(ps aux | grep [n]vidia-smi | wc -l )
	if [ $busy -eq 0 ]
	then
		count=$(sudo nvidia-smi -i 0 --query-gpu=count --format=csv,noheader,nounits)
		nvidia-settings -a "GPUFanControlState=1" > /dev/null 2>&1
		nvidia-settings -a "GPUTargetFanSpeed="$start_speed > /dev/null 2>&1
	else
		sleep 1
	fi
done

error_flag=0
error_count=0

while (true)
do
clear

if [ $error_flag -ne 0 ]
then
	error_count=$(( $error_count + 1 ))
else
	error_count=0
fi

if [ $error_count -ne 0 ]
then
	echo "WARNING!!! Lost Card or using Card low."
	if [ $watch_dog -eq 1 ]
	then
		remain_in_cicle=$(( $error_level - $error_count ))
		remain_in_sec=$(( $remain_in_cicle * $PAUSE ))
		if [ $remain_in_cicle -le 0 ]
		then
			echo "Reboot NOW!"
			echo $(date +%d-%m-%Y\ %H:%M:%S) $error_msg >> ~/watchdog.log
			sudo reboot
		else 
			echo "Reboot in "$remain_in_sec" sec!"
		fi
	else
		echo "WatchDog disabled"
	fi
else
	if [ $watch_dog -eq 1 ]
		then
		echo "WatchDog enabled. All OK"
	else
		echo "WatchDog disabled"
	fi
fi

error_flag=0

res_req=0
busy=1

while [ $busy -ne 0 ]
do
	busy=$(ps aux | grep [n]vidia-smi | wc -l )
	if [ $busy -eq 0 ]
	then
		all_fan=($(echo "$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits)" | tr ' ' '\n'))
		res_req=$?
		if [ $res_req -ne 0 ]
		then
			echo "Error get data from cards"
			error_flag=1
			error_msg="Error get data from cards"
			continue 2
		fi
		all_temp=($(echo "$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)" | tr ' ' '\n'))
		all_using=($(echo "$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)" | tr ' ' '\n'))
		all_control=($(echo "$(nvidia-settings -q GPUFanControlState -t)" | tr ' ' '\n'))
	else
		sleep 1
	fi
done

for (( i=0; i < $count; i++ ))
do
	fan=${all_fan[$i]}
	temp=${all_temp[$i]}
	using=${all_using[$i]}
	control=${all_control[$i]}

	echo
	if [ $using -lt $min_using ]
	then
		error_flag=1
		error_msg="Using card "$using"%"
	fi

	echo "Using Card "$i": "$using"%."
	
	if [ $temp -ge $high_level ]
	then
		if [ $fan -ge $max_fan ]
		then
			echo "Fan speed "$i": "$fan".Temperature "$i": "$temp" !!!!!!!"
			continue
		fi
		speed=$(( $fan + 2 ))
		if [ $speed -gt $max_fan ]
		then
			speed=$max_fan
		fi

		if [ $temp -ge $very_high_level ]
		then
			if [ $fan -lt $very_high_fan ]
			then
				speed=$very_high_fan
			fi
		fi
		echo "Fan "$i": "$fan" Temperature "$i": "$temp ". Is very high! Increase fan speed to "$speed
		if [ $control -eq 0 ]
		then
			nvidia-settings -a "[gpu:"$i"]/GPUFanControlState=1" > /dev/null 2>&1
		fi
		nvidia-settings -a "[fan:"$i"]/GPUTargetFanSpeed="$speed > /dev/null 2>&1
		continue
	fi

	if [ $temp -lt $low_level ]
	then
		if [ $fan -le $min_fan ]
		then
			if [ $control -ne 0 ]
			then
				nvidia-settings -a "[gpu:"$i"]/GPUFanControlState=0" > /dev/null 2>&1
			fi
			echo "Fan "$i": "$fan" Temperature "$i": "$temp
			continue
		else
			if [ $control -ne 0 ]
			then
				speed=$(( $fan - 1 ))
				nvidia-settings -a "[fan:"$i"]/GPUTargetFanSpeed="$speed > /dev/null 2>&1
				echo "Fan "$i": "$fan" Temperature "$i": "$temp ". Is very low! Decrease fan speed to "$speed
				continue
			fi
		fi
	fi

	echo "Fan "$i": "$fan" Temperature "$i": "$temp

done

sleep $PAUSE
done
