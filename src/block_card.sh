#!/bin/bash
base="isql-fb -u ${2} -p ${3} -r admin ${4}:${5}";
SQL="update usr\$mn_staffcard set usr\$disabled=1, usr\$enddate='$(date +'%d.%m.%Y')' where usr\$code= ${1} ;";
result=`echo $SQL | $base 2>&1`;
if [[ $result == *"08006"* ]]; then
exit 101; # Нет соединения с сервером
fi;
if [[ $result == *"08001"* ]]; then
exit 102; # Не найдена БД на сервере
fi;
if [[ $result == *"Dynamic SQL"* ]]; then
exit 103; # Ошибка при выполнении SQL-запроса
fi;
if [[ $result == *"Count returns 0"* ]]; then
exit 104; # В базе данных не найдена запись
fi;
# Получаем табелньный по номеру карты
SQL="select usr\$number from usr\$mn_staffcard where usr\$code = ${1} ;";
result=`echo $SQL | $base 2>&1`;
if [[ $result == *"08006"* ]]; then
exit 101; # Нет соединения с сервером
fi;
if [[ $result == *"08001"* ]]; then
exit 102; # Не найдена БД на сервере
fi;
if [[ $result == *"Dynamic SQL"* ]]; then
exit 105; # Ошибка при выполнении SQL-запроса
fi;
if [[ $result == "" ]]; then
exit 104; # В базе данных не найдена запись
fi;
tabnum=$(grep -oE "[0-9.]{1,}" <<< $result); # парсим результат запроса, оставляем только числа
# Получаем выгрузку за день по табельному
SQL="select
    pl.USR\$TABNUM as TabNum,
    Sum(IIF(COALESCE(o.USR\$RETURN, 0) = 1, -p.USR\$SUMNCU, p.USR\$SUMNCU)) as Sumncu
    from
    usr\$mn_order o
    left join gd_contact con on con.id = o.USR\$STAFFKEY
    join gd_people pl on pl.CONTACTKEY = con.id
    join usr\$mn_payment p on p.USR\$ORDERKEY = o.DOCUMENTKEY
    where
    o.usr\$pay = 1
    and COALESCE(o.USR\$RETURN, 0) = 0
    AND NOT EXISTS(SELECT ol.MASTERKEY FROM USR\$MN_ORDERLINE ol WHERE ol.MASTERKEY = o.DOCUMENTKEY AND ol.USR\$REFUND = 1)
    AND pl.USR\$TABNUM = $tabnum
    and o.usr\$logicdate = CURRENT_DATE
    and p.USR\$PAYKINDKEY = 147015737
    GROUP BY
    con.name, pl.USR\$TABNUM
    order by
    con.name;"
result=`echo $SQL | $base 2>&1`;
if [[ $result == *"08006"* ]]; then
exit 101; # Нет соединения с сервером
fi;
if [[ $result == *"08001"* ]]; then
exit 102; # Не найдена БД на сервере
fi;
if [[ $result == *"Dynamic SQL"* ]]; then
exit 106; # Ошибка при выполнении SQL-запроса
fi;
if [[ $result == "" ]]; then
exit 107; # В базе данных не найдена запись
fi;
row=$(grep -oE "[0-9.]{1,}" <<< $result); # парсим результат запроса, оставляем только числа
row=${row//./,}; # заменяем точки на запятые
row=$(echo $row | tr " " ";"); # заменяем пробелы на разделитель
row="$(date +'%d.%m.%Y');$row"; # формируем итоговою строку с датой, табельным и суммой
file="$(date +'%Y%m%d')_${1}_block_cardsales.csv"
cat <<END >$file
$row
END
scp -i /var/www/ssh/id_rsa -o UserKnownHostsFile=/var/www/ssh/known_hosts $file sync-user@192.168.2.133:/usr/sap/VOC/;
mv $file /logs/Reports
