FROM intersystemsdc/irishealth-community

WORKDIR /home/irisowner/zprofile

RUN --mount=type=bind,src=.,dst=. \
  iris start iris && \
  ./init.db/10_foundtation.sh && \
  ./init.db/20_fhirserver.sh && \
  ./init.db/50_module.sh && \
  ./init-demo.sh && \
  iris stop iris quietly

