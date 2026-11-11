import pytest

import app.modules.analitica.service as analitica


@pytest.fixture(autouse=True)
def sin_google_analytics(monkeypatch):
    """Tests never send events to the real Google Analytics property."""
    enviados = []
    monkeypatch.setattr(
        analitica, "enviar_a_ga", lambda evento, props: enviados.append((evento, props))
    )
    return enviados
