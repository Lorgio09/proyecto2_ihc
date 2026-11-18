import pytest

import app.modules.analitica.service as analitica


@pytest.fixture(autouse=True)
def sin_google_analytics(monkeypatch):
    """Las pruebas nunca envían eventos a la propiedad real de Google Analytics."""
    enviados = []
    monkeypatch.setattr(
        analitica, "enviar_a_ga", lambda evento, props: enviados.append((evento, props))
    )
    return enviados
