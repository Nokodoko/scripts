#!/bin/bash
#
COMMAND=$(fd -tf ingress.yaml .)
#UPDATE=$(fd -tf ingress.yaml . -x xargs $(cat $SCRIPT >>))
#SCRIPT='~/helper.sh'
#pushd /home/n0ko/capacity/repos/dev/ops/helm-deployments
#
##1. UPDATE NETWORKING LINE
#fd -tf ingress.yaml . -x sed -i 's/apiVer.*/apiVersion: networking.k8s.io\/v1/'
#if [ $? -ne 0 ]; then
#    echo "apiVersion success"
#else
#    echo "apiVersion failed"
#fi
#
##2. UPDATE PATHTYPE
#fd -tf ingress.yaml . -x sed -i '/\$ingressPath/,$d'
#if [ $? -ne 0 ]; then
#    echo "ingressPath success"
#else
#    echo "ingressPath failed"
#fi
#
##3. UPDATE FROM BACKEND DOWN TO EOF
##remove from under -path: {{ $ingressPath}} to EOF
#echo " - path: {{ $ingressPath }}
#            pathType: ImplementationSpecific
#            backend:
#              service:
#                name: {{ $serviceName }}
#                port:
#                  number: {{ $servicePort }}
#    {{- end -}}
#{{- if .Values.ingress.tls }}
#  tls:
#{{ toYaml .Values.ingress.tls | indent 4 }}
#  {{- end -}}" >> $SCRIPT
#if [ $? -ne 0 ]; then
#    echo "append success"
#else
#    echo "append failed"
#fi
#
#$UPDATE
#
#rm $SCRIPT
#
#
#exceptions:
#rabbitmq
#1. UPDATE NETWORKING LINE
fd -tf ingress.yaml . -x sed -i 's/apiVer.*/apiVersion: networking.k8s.io\/v1/'
if [ $? -ne 0 ]; then
    echo "apiVersion success"
else
    echo "apiVersion failed"
fi

#2. UPDATE PATHTYPE
fd -tf ingress.yaml . -x sed -i '/\paths:/,$d'
if [ $? -ne 0 ]; then
    echo "ingressPath success"
else
    echo "ingressPath failed"
fi

#3. UPDATE FROM BACKEND DOWN TO EOF
#remove from under -path: {{ $ingressPath}} to EOF
echo "        paths:
          - path: {{ \$ingressPath }}
            pathType: ImplementationSpecific
            backend:
              service:
                name: {{ \$serviceName }}
                port:
                  number: {{ \$servicePort }}
    {{- end -}}
{{- if .Values.ingress.tls }}
  tls:
{{ toYaml .Values.ingress.tls | indent 4 }}
  {{- end -}}
" > ~/helper.sh
if [ $? -ne 0 ]; then
    echo "echo success"
else
    echo "echo failed"
fi

echo "#!/bin/bash

cat ~/helper.sh >> \$(fd -tf ingress.yaml /home/n0ko/capacity/repos/dev/ops/helm-deployments)" > ~/anotherHelper.sh

chmod +x ~/anotherHelper.sh
~/anotherHelper.sh

$COMMAND -x sed -i 's/^$/d'

#rm ~/helper.sh
#rm ~/anotherHelper.sh
#fd -tf ingress.yaml /home/n0ko/capacity/repos/dev/ops/helm-deployments > ~/list.md
#LIST='~/list.md'
#while $LIST= read -r line; do
#    cat ~/helper.sh $line >> 
#done
#xargs -l cat ~/helper.sh << $(fd -tf ingress.yaml /home/n0ko/capacity/repos/dev/ops/helm-deployments)


#rm $SCRIPT
#rm $FILES
