#!/bin/bash
VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: ./deploy.sh v1.0.0"
    exit 1
fi

#docker build --no-cache -t finallf/perforce:$VERSION .
docker build -t "finallf/perforce:$VERSION" .

docker tag "finallf/perforce:$VERSION" finallf/perforce:latest

docker push "finallf/perforce:$VERSION"
docker push finallf/perforce:latest

echo "Deploy of version $VERSION and latest complete!"
