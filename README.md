# Nimbul Scripts

This project is useful for syncing nimbul start scripts/code.

**IMPORTANT** - Create a scripts/.aws_creds file that contains a valid AWS_SECRET pair and your nimbul 3 token e.g.

```
> cat scripts/.aws_creds 
AWS_ACCESS_KEY_ID=AKI#############GJAA
AWS_SECRET_ACCESS_KEY=LZa##############################bvU+fRr
TOKEN=ed2#########################1930
```

If you haven't run this tool before start by running the following to bring down all of your scripts from S3

```
scripts/sync.sh -e dev -d down -t du
```

Then you can edit scripts in remote/ to get them where you need them and then run

```
scripts/sync.sh -e dev -d up -t du -a <your app>
```

If you need to re-bootstrap an instance you can run

```
scripts/bootstrap.sh -i 1234
```

Replace 1234 with the instance ID that's in nimubl **NOT** the i-1234


