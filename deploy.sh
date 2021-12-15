#!/bin/sh
rm -rf public/ &&
yarn build &&
pwd &&
zip -q -r -o public.zip public &&
#scp -i '/Users/jiabinbin/.ssh/root' public.zip root@163.53.219.60:/root/website/blog/ &&
scp -i '/Users/jiabinbin/.ssh/root' public.zip root@115.126.75.120:/www/admin/yuexiaoya.cn_80/ &&
#ssh -i '/Users/jiabinbin/.ssh/root' root@163.53.219.60 'cd /root/website/blog/ ; ./deploy.sh' &&
ssh -i '/Users/jiabinbin/.ssh/root' root@115.126.75.120 'cd /www/admin/yuexiaoya.cn_80/ ; ./deploy.sh' &&
rm -rf public.zip &&
git status &&
git add . &&
git status &&
git commit -m 'update blog' &&
git push origin main &&
echo 'task finished'
##
